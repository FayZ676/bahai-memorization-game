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
    private(set) var isSettling = false
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

    func start(words: [String], hiddenIndices: [Int]) async {
        guard !hiddenIndices.isEmpty else { return }
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        state = .preparingModel
        do {
            await prewarmTask?.value
            let transcriber = Self.makeTranscriber()
            try await Self.ensureModelInstalled(for: transcriber)
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            guard state == .preparingModel else { return }
            matcher = RecitationMatcher(words: words, hiddenIndices: hiddenIndices)
            heardText = ""
            nextExpectedIndex = matcher.nextExpectedIndex
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.analyzerOptions)
            self.transcriber = transcriber
            self.analyzer = analyzer
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            guard state == .preparingModel else { return }
            try Self.activateAudioSession()
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputBuilder = inputBuilder
            try startAudioEngine(feeding: inputBuilder, format: analyzerFormat)
            try await analyzer.start(inputSequence: inputSequence)
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
        let tokens = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        heardText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSettling = false
        finalizeDebounce?.cancel()
        if result.isFinal {
            dispatch(matcher.finalizeSegment(tokens))
        } else {
            dispatch(matcher.updateVolatile(tokens))
            scheduleIdleFinalize()
        }
        nextExpectedIndex = matcher.nextExpectedIndex
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
        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
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

    private static func makeTranscriber() -> SpeechTranscriber {
        SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
    }

    private static func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws {
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
