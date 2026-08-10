import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class VoiceRecitationController {
    enum State: Equatable {
        case idle
        case preparingModel
        case listening
        case micDenied
        case failed
    }

    private(set) var state: State = .idle
    private(set) var nextExpectedIndex: Int?
    private(set) var heardText = ""
    var onWordsMatched: (([Int]) -> Void)?
    var onMiss: ((Int, Bool) -> Void)?
    var onCompleted: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var finalizeDebounce: Task<Void, Never>?
    private var readyTask: Task<Ready?, Never>?
    private var readyText: String?
    private var passageInUse: String?
    private var matcher = RecitationMatcher(words: [], hiddenIndices: [])

    var isListening: Bool { state == .listening }

    private struct Ready {
        let transcriber: DictationTranscriber
        let analyzer: SpeechAnalyzer
        let format: AVAudioFormat?
    }

    func prepare(for text: String) {
        guard readyText != text else { return }
        readyText = text
        let previous = readyTask
        readyTask = Task {
            if let stale = await previous?.value { await stale.analyzer.cancelAndFinishNow() }
            let customization = await RecitationLanguageModel.shared.configuration(for: text)
            let transcriber = Self.makeTranscriber(customizing: customization)
            try? await Self.ensureModelInstalled(for: transcriber)
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.analyzerOptions)
            let context = AnalysisContext()
            context.contextualStrings = [
                .general: RecitationContext.contextualStrings(
                    for: text,
                    hidden: Set(Reviewable.tokens(in: text).indices)
                )
            ]
            try? await analyzer.setContext(context)
            try? await analyzer.prepareToAnalyze(in: format)
            return Ready(transcriber: transcriber, analyzer: analyzer, format: format)
        }
    }

    func start(
        words: [String],
        contextText: String,
        passageText: String,
        hiddenIndices: [Int]
    ) async {
        guard !hiddenIndices.isEmpty else { return }
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        state = .preparingModel
        do {
            let clock = ContinuousClock.now
            var marks: [String] = []
            func mark(_ label: String) {
                #if DEBUG
                let elapsed = clock.duration(to: .now)
                let ms = Double(elapsed.components.seconds) * 1000
                    + Double(elapsed.components.attoseconds) / 1e15
                marks.append(String(format: "%@=%.0fms", label, ms))
                #endif
            }
            prepare(for: passageText)
            guard let ready = await readyTask?.value else { throw CancellationError() }
            readyTask = nil
            readyText = nil
            mark("ready")
            passageInUse = passageText
            let transcriber = ready.transcriber
            let analyzer = ready.analyzer
            let analyzerFormat = ready.format
            guard state == .preparingModel else {
                await analyzer.cancelAndFinishNow()
                return
            }
            matcher = RecitationMatcher(words: words, hiddenIndices: hiddenIndices)
            heardText = ""
            nextExpectedIndex = matcher.nextExpectedIndex
            self.transcriber = transcriber
            self.analyzer = analyzer
            guard state == .preparingModel else { return }
            try Self.activateAudioSession()
            mark("session")
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputBuilder = inputBuilder
            try startAudioEngine(feeding: inputBuilder, format: analyzerFormat)
            try await analyzer.start(inputSequence: inputSequence)
            mark("start")
            state = .listening
            #if DEBUG
            print("RECITE start \(marks.joined(separator: " "))")
            #endif
            observeResults(from: transcriber)
        } catch {
            state = .failed
            teardown()
        }
    }

    func updateHiddenIndices(_ hiddenIndices: [Int]) {
        guard state == .listening else { return }
        matcher.replaceHidden(with: hiddenIndices)
        nextExpectedIndex = matcher.nextExpectedIndex
        if matcher.isComplete { stop() }
    }

    func stop() {
        guard state != .idle else { return }
        if state != .micDenied {
            state = .idle
        }
        teardown()
        if let passageInUse { prepare(for: passageInUse) }
    }

    func release() {
        stop()
        passageInUse = nil
        readyText = nil
        let pending = readyTask
        readyTask = nil
        Task { if let ready = await pending?.value { await ready.analyzer.cancelAndFinishNow() } }
    }

    private func observeResults(from transcriber: DictationTranscriber) {
        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    guard state == .listening else { return }
                    ingest(result)
                    if matcher.isComplete {
                        stop()
                        onCompleted?()
                        return
                    }
                }
            } catch {
                guard state == .listening else { return }
                state = .failed
                teardown()
            }
        }
    }

    private func ingest(_ result: DictationTranscriber.Result) {
        heardText = String(result.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        dispatch(matcher.ingest(Self.tokens(in: result.text), isFinal: result.isFinal))
        nextExpectedIndex = matcher.nextExpectedIndex
        if !result.isFinal { scheduleIdleFinalize() }
    }

    private func scheduleIdleFinalize() {
        finalizeDebounce?.cancel()
        finalizeDebounce = Task {
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, state == .listening, let analyzer else { return }
            try? await analyzer.finalize(through: nil)
        }
    }

    private static func tokens(in text: AttributedString) -> [RecitationMatcher.HeardToken] {
        text.runs.flatMap { run in
            String(text[run.range].characters)
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map {
                    RecitationMatcher.HeardToken(
                        text: $0,
                        confidence: run.transcriptionConfidence ?? 1
                    )
                }
        }
    }

    private func dispatch(_ events: [RecitationMatcher.Event]) {
        #if DEBUG
        if !events.isEmpty { print("RECITE events \(events) heard=\(heardText)") }
        #endif
        for event in events {
            switch event {
            case .matched(let index):
                onWordsMatched?([index])
            case .missed(let index, let movedOn):
                onMiss?(index, movedOn)
            }
        }
    }

    private func startAudioEngine(
        feeding inputBuilder: AsyncStream<AnalyzerInput>.Continuation,
        format analyzerFormat: AVAudioFormat?
    ) throws {
        let input = audioEngine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        guard let analyzerFormat,
              let converter = AVAudioConverter(from: tapFormat, to: analyzerFormat) else {
            throw CancellationError()
        }
        converter.primeMethod = .none
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            guard let converted = Self.converted(buffer, with: converter, to: analyzerFormat) else { return }
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func teardown() {
        resultsTask?.cancel()
        resultsTask = nil
        finalizeDebounce?.cancel()
        finalizeDebounce = nil
        inputBuilder?.finish()
        inputBuilder = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        let analyzer = analyzer
        self.analyzer = nil
        transcriber = nil
        Task { await analyzer?.cancelAndFinishNow() }
        Self.deactivateAudioSession()
        nextExpectedIndex = nil
        heardText = ""
    }

    private nonisolated static func converted(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var pending: AVAudioPCMBuffer? = buffer
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            guard let next = pending else {
                status.pointee = .noDataNow
                return nil
            }
            pending = nil
            status.pointee = .haveData
            return next
        }
        return conversionError == nil ? output : nil
    }

    private static let analyzerOptions = SpeechAnalyzer.Options(
        priority: .userInitiated,
        modelRetention: .processLifetime
    )

    private static func makeTranscriber(
        customizing configuration: SFSpeechLanguageModel.Configuration? = nil
    ) -> DictationTranscriber {
        var preset = DictationTranscriber.Preset.progressiveShortDictation
        preset.reportingOptions = [.volatileResults, .frequentFinalization]
        preset.attributeOptions = [.audioTimeRange, .transcriptionConfidence]
        if let configuration {
            preset.contentHints.insert(.customizedLanguage(modelConfiguration: configuration))
        }
        return DictationTranscriber(locale: Locale(identifier: "en-US"), preset: preset)
    }

    private static func ensureModelInstalled(for transcriber: DictationTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    private static func micPermissionGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }

    private static func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)
    }

    private static func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
