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
    private var prewarmTask: Task<Void, Never>?
    private var listeningSince: ContinuousClock.Instant?
    private var lastResultAt: ContinuousClock.Instant?
    private var matcher = RecitationMatcher(words: [], hiddenIndices: [])

    var isListening: Bool { state == .listening }

    func prewarm() {
        guard prewarmTask == nil else { return }
        prewarmTask = Task {
            let transcriber = Self.makeTranscriber()
            try? await Self.ensureModelInstalled(for: transcriber)
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.analyzerOptions)
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            try? await analyzer.prepareToAnalyze(in: format)
            await analyzer.cancelAndFinishNow()
        }
    }

    func start(words: [String], contextText: String, hiddenIndices: [Int]) async {
        guard !hiddenIndices.isEmpty else { return }
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        state = .preparingModel
        do {
            await prewarmTask?.value
            let customization = await RecitationLanguageModel.configuration(for: contextText)
            #if DEBUG
            print("RECITE customization \(customization == nil ? "unavailable" : "ready")")
            #endif
            guard state == .preparingModel else { return }
            let transcriber = Self.makeTranscriber(customizing: customization)
            try await Self.ensureModelInstalled(for: transcriber)
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            guard state == .preparingModel else { return }
            matcher = RecitationMatcher(words: words, hiddenIndices: hiddenIndices)
            heardText = ""
            nextExpectedIndex = matcher.nextExpectedIndex
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.analyzerOptions)
            self.transcriber = transcriber
            self.analyzer = analyzer
            let context = AnalysisContext()
            context.contextualStrings = [
                .general: RecitationContext.contextualStrings(
                    for: contextText,
                    hidden: Set(hiddenIndices)
                )
            ]
            try await analyzer.setContext(context)
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            guard state == .preparingModel else { return }
            try Self.activateAudioSession()
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputBuilder = inputBuilder
            try startAudioEngine(feeding: inputBuilder, format: analyzerFormat)
            try await analyzer.start(inputSequence: inputSequence)
            listeningSince = .now
            state = .listening
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
        let tokens = Self.tokens(in: result.text)
        let before = matcher.diagnostic
        let started = ContinuousClock.now
        let gap = lastResultAt?.duration(to: started)
        lastResultAt = started
        let events = matcher.ingest(tokens, isFinal: result.isFinal)
        Self.trace(
            result: result,
            tokens: tokens,
            before: before,
            events: events,
            compute: started.duration(to: .now),
            sinceListening: listeningSince?.duration(to: .now),
            gap: gap
        )
        dispatch(events)
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

    private static func trace(
        result: DictationTranscriber.Result,
        tokens: [RecitationMatcher.HeardToken],
        before: String,
        events: [RecitationMatcher.Event],
        compute: Duration,
        sinceListening: Duration?,
        gap: Duration?
    ) {
        #if DEBUG
        func millis(_ duration: Duration) -> String {
            String(format: "%.1fms", Double(duration.components.attoseconds) / 1e15
                + Double(duration.components.seconds) * 1000)
        }
        let audioCovered = result.range.end.seconds
        let pipeline = sinceListening.map { elapsed -> String in
            let wall = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
            return audioCovered.isFinite ? String(format: "%.0fms", (wall - audioCovered) * 1000) : "?"
        } ?? "?"
        let described = tokens.map {
            "\($0.text)/\($0.key)c\(String(format: "%.2f", $0.confidence))"
        }
        print("RECITE final=\(result.isFinal) n=\(tokens.count) gap=\(gap.map(millis) ?? "-") compute=\(millis(compute)) pipeline=\(pipeline) \(before)")
        print("RECITE   tokens \(described.joined(separator: " "))")
        print("RECITE   events \(events)")
        #endif
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
        for event in events {
            switch event {
            case .matched(let index):
                onWordsMatched?([index])
            case .missed(let index, let movedOn):
                onMiss?(index, movedOn)
            }
        }
    }

    private final class TapMeter: @unchecked Sendable {
        private var callbacks = 0
        private var frames = 0
        private var last = ContinuousClock.now

        func record(_ delta: Int) {
            callbacks += 1
            frames += delta
            let elapsed = last.duration(to: .now)
            guard elapsed > .seconds(1) else { return }
            let seconds = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18
            print(String(
                format: "RECITE tap callbacks=%d frames=%d over %.2fs (every %.0fms)",
                callbacks, frames, seconds, seconds * 1000 / Double(callbacks)
            ))
            callbacks = 0
            frames = 0
            last = .now
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
        let meter = TapMeter()
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            #if DEBUG
            meter.record(Int(buffer.frameLength))
            #endif
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
