import AVFoundation
import CoreMedia
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
    private(set) var isSettling = false
    private(set) var downloadProgress: Double?
    var onWordsMatched: (([Int]) -> Void)?
    var onMiss: ((Int, Bool) -> Void)?
    var onCompleted: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var finalizeDebounce: Task<Void, Never>?
    private var prewarmTask: Task<Void, Never>?
    private var disruptionObservers: [NSObjectProtocol] = []
    private var matcher = RecitationMatcher(words: [], hiddenIndices: [])
    private var consumption = TranscriptConsumption()

    var isListening: Bool { state == .listening }

    func prewarm() {
        guard prewarmTask == nil else { return }
        prewarmTask = Task { [weak self] in
            guard let locale = await Self.resolveLocale() else { return }
            let transcriber = Self.makeTranscriber(locale: locale)
            try? await self?.installModelIfNeeded(for: transcriber)
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
        guard SpeechTranscriber.isAvailable else {
            state = .failed
            return
        }
        state = .preparingModel
        do {
            await prewarmTask?.value
            guard let locale = await Self.resolveLocale() else {
                state = .failed
                return
            }
            let transcriber = Self.makeTranscriber(locale: locale)
            try await installModelIfNeeded(for: transcriber)
            _ = try? await AssetInventory.reserve(locale: locale)
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            guard state == .preparingModel else { return }
            matcher = RecitationMatcher(words: words, hiddenIndices: hiddenIndices)
            consumption = TranscriptConsumption()
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
            state = .listening
            observeAudioDisruptions()
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

    private func observeResults(from transcriber: SpeechTranscriber) {
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

    private func ingest(_ result: SpeechTranscriber.Result) {
        let text = String(result.text.characters)
        heardText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSettling = false
        finalizeDebounce?.cancel()
        let timed = Self.timedTokens(in: result.text, fallbackEnd: result.range.end.seconds)
        let pending = consumption.pending(in: timed)
        if !pending.isEmpty {
            matcher.resetSegmentCursor()
            let words = pending.map(\.text)
            if result.isFinal {
                let alternatives = result.alternatives.map { Self.tokenize(String($0.characters)) }
                dispatch(matcher.finalizeSegment(words, alternatives: alternatives))
            } else {
                dispatch(matcher.updateVolatile(words))
            }
            consumption.advance(over: pending, committed: matcher.segmentCursor)
        }
        if !result.isFinal { scheduleIdleFinalize() }
        nextExpectedIndex = matcher.nextExpectedIndex
    }

    private static func timedTokens(
        in text: AttributedString,
        fallbackEnd: Double
    ) -> [TimedToken] {
        var timed: [TimedToken] = []
        var lastEnd = -Double.greatestFiniteMagnitude
        for run in text.runs {
            let piece = String(text[run.range].characters)
            let end = run.audioTimeRange?.end.seconds ?? lastEnd
            for token in piece.split(whereSeparator: \.isWhitespace) {
                timed.append(TimedToken(text: String(token), end: end))
            }
            lastEnd = end
        }
        for index in timed.indices where timed[index].end == -Double.greatestFiniteMagnitude {
            timed[index].end = fallbackEnd
        }
        return timed
    }

    private func scheduleIdleFinalize() {
        finalizeDebounce = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, state == .listening, let analyzer else { return }
            isSettling = true
            try? await analyzer.finalize(through: nil)
            isSettling = false
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

    private static func tokenize(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private func observeAudioDisruptions() {
        let names: [Notification.Name] = [
            AVAudioSession.interruptionNotification,
            AVAudioSession.mediaServicesWereResetNotification,
            .AVAudioEngineConfigurationChange,
        ]
        disruptionObservers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
        }
    }

    private func removeDisruptionObservers() {
        for observer in disruptionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        disruptionObservers = []
    }

    private func installModelIfNeeded(for transcriber: SpeechTranscriber) async throws {
        guard let request = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) else { return }
        let progress = request.progress
        let poller = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.downloadProgress = progress.fractionCompleted
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer {
            poller.cancel()
            downloadProgress = nil
        }
        try await request.downloadAndInstall()
    }

    private func teardown() {
        removeDisruptionObservers()
        resultsTask?.cancel()
        resultsTask = nil
        finalizeDebounce?.cancel()
        finalizeDebounce = nil
        isSettling = false
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

    private static func resolveLocale() async -> Locale? {
        await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
    }

    private static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults, .alternativeTranscriptions],
            attributeOptions: [.audioTimeRange]
        )
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
