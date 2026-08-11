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

    private(set) var state: State = .idle {
        didSet { RecitationTrace.emit("state", "\(oldValue) -> \(state)") }
    }
    private(set) var nextExpectedIndex: Int?
    private(set) var cursorIndex: Int?
    private(set) var heardText = ""
    var onWordsMatched: (([Int]) -> Void)?
    var onMiss: ((Int, Bool) -> Void)?
    var onCompleted: (() -> Void)?
    var onAttemptFinished: ((RecitationDraft) -> Void)?

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
    private var listeningSince = Date()
    private var lastResultAt = Date()
    private var resultCount = 0

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
        RecitationTrace.emit("prepare", "begin for \(text.prefix(40))… (\(text.count) chars)")
        readyTask = Task {
            if let stale = await previous?.value {
                await RecitationTrace.measure("prepare", "cancel stale analyzer") {
                    await stale.analyzer.cancelAndFinishNow()
                }
            }
            let customization = await RecitationTrace.measure("prepare", "language model") {
                await RecitationLanguageModel.shared.configuration(for: text)
            }
            RecitationTrace.emit("prepare", "customization=\(customization != nil)")
            let transcriber = Self.makeTranscriber(customizing: customization)
            await RecitationTrace.measure("prepare", "ensure model installed") {
                try? await Self.ensureModelInstalled(for: transcriber)
            }
            let format = await RecitationTrace.measure("prepare", "best audio format") {
                await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            }
            RecitationTrace.emit("prepare", "analyzer format=\(format?.description ?? "nil")")
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: Self.analyzerOptions)
            let context = AnalysisContext()
            let strings = RecitationContext.contextualStrings(
                for: text,
                hidden: Set(Reviewable.tokens(in: text).indices)
            )
            RecitationTrace.emit("prepare", "contextualStrings=\(strings.count)")
            context.contextualStrings = [.general: strings]
            await RecitationTrace.measure("prepare", "setContext") {
                try? await analyzer.setContext(context)
            }
            await RecitationTrace.measure("prepare", "prepareToAnalyze") {
                try? await analyzer.prepareToAnalyze(in: format)
            }
            RecitationTrace.emit("prepare", "ready")
            return Ready(transcriber: transcriber, analyzer: analyzer, format: format)
        }
    }

    func start(
        words: [String],
        contextText: String,
        passageText: String,
        hiddenIndices: [Int]
    ) async {
        RecitationTrace.begin()
        RecitationTrace.emit(
            "start",
            """
            words=\(words.count) hidden=\(hiddenIndices) state=\(state) \
            expecting=[\(hiddenIndices.compactMap { words.indices.contains($0) ? "\($0):\(words[$0])" : nil }.joined(separator: " "))]
            """
        )
        RecitationTrace.emit("start", "keys=[\(words.map(PhoneticKey.encode).joined(separator: " "))]")
        guard !hiddenIndices.isEmpty else { return }
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        let startedAt = Date()
        state = .preparingModel
        do {
            prepare(for: passageText)
            guard let ready = await RecitationTrace.measure("start", "await ready", { await readyTask?.value })
            else { throw CancellationError() }
            RecitationTrace.emit("start", "ready after \(RecitationTrace.ms(since: startedAt))")
            readyTask = nil
            readyText = nil
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
            cursorIndex = matcher.cursorIndex
            self.transcriber = transcriber
            self.analyzer = analyzer
            guard state == .preparingModel else { return }
            try RecitationTrace.measure("start", "activate audio session") { try Self.activateAudioSession() }
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputBuilder = inputBuilder
            try RecitationTrace.measure("start", "audio engine") {
                try startAudioEngine(feeding: inputBuilder, format: analyzerFormat)
            }
            try await RecitationTrace.measure("start", "analyzer.start") {
                try await analyzer.start(inputSequence: inputSequence)
            }
            state = .listening
            listeningSince = Date()
            lastResultAt = Date()
            resultCount = 0
            observeResults(from: transcriber)
            RecitationTrace.emit("start", "listening after \(RecitationTrace.ms(since: startedAt))")
        } catch {
            RecitationTrace.emit("start", "FAILED \(error)")
            state = .failed
            teardown()
        }
    }

    func updateHiddenIndices(_ hiddenIndices: [Int]) {
        guard state == .listening else { return }
        RecitationTrace.emit("hidden", "updateHiddenIndices \(hiddenIndices)")
        matcher.replaceHidden(with: hiddenIndices)
        nextExpectedIndex = matcher.nextExpectedIndex
        cursorIndex = matcher.cursorIndex
        if matcher.isComplete { stop() }
    }

    func stop() {
        RecitationTrace.emit("stop", "state=\(state) results=\(resultCount)")
        guard state != .idle else { return }
        if state != .micDenied {
            state = .idle
        }
        reportAttempt()
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

    private func reportAttempt() {
        let draft = RecitationDraft(
            expectedCount: matcher.expectedCount,
            matchedCount: matcher.matchedCount,
            misses: matcher.misses,
            transcript: matcher.transcript
        )
        guard !draft.isEmpty else { return }
        matcher = RecitationMatcher(words: [], hiddenIndices: [])
        onAttemptFinished?(draft)
    }

    private func observeResults(from transcriber: DictationTranscriber) {
        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    guard state == .listening else {
                        RecitationTrace.emit("result", "dropped, state=\(state)")
                        return
                    }
                    ingest(result)
                    if matcher.isComplete {
                        RecitationTrace.emit("result", "matcher complete, stopping")
                        stop()
                        onCompleted?()
                        return
                    }
                }
                RecitationTrace.emit("result", "stream ended after \(resultCount) results")
            } catch {
                RecitationTrace.emit("result", "stream ERROR \(error)")
                guard state == .listening else { return }
                state = .failed
                teardown()
            }
        }
    }

    private func ingest(_ result: DictationTranscriber.Result) {
        resultCount += 1
        let tokens = Self.tokens(in: result.text)
        RecitationTrace.emit(
            "result",
            """
            #\(resultCount) \(result.isFinal ? "FINAL" : "vol  ") \
            gap=\(RecitationTrace.ms(since: lastResultAt)) since-start=\(RecitationTrace.ms(since: listeningSince)) \
            runs=\(result.text.runs.count) range=\(result.range) \
            text="\(String(result.text.characters))" \
            tokens=[\(tokens.map { "\($0.key)@\(String(format: "%.2f", $0.confidence))" }.joined(separator: " "))]
            """
        )
        lastResultAt = Date()
        heardText = String(result.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ingestStarted = Date()
        let events = matcher.ingest(tokens, isFinal: result.isFinal)
        RecitationTrace.emit(
            "matcher",
            """
            events=\(events) owed=\(matcher.nextExpectedIndex.map(String.init) ?? "-") \
            cursor=\(matcher.cursorIndex.map(String.init) ?? "-") in \(RecitationTrace.ms(since: ingestStarted))
            """
        )
        dispatch(events)
        nextExpectedIndex = matcher.nextExpectedIndex
        cursorIndex = matcher.cursorIndex
        if !result.isFinal { scheduleIdleFinalize() }
    }

    private func scheduleIdleFinalize() {
        finalizeDebounce?.cancel()
        finalizeDebounce = Task {
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, state == .listening, let analyzer else { return }
            RecitationTrace.emit("finalize", "idle 1200ms, forcing finalize")
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
        RecitationTrace.emit("audio", "tap format=\(tapFormat) analyzer format=\(analyzerFormat?.description ?? "nil")")
        guard let analyzerFormat,
              let converter = AVAudioConverter(from: tapFormat, to: analyzerFormat) else {
            RecitationTrace.emit("audio", "FAILED to build converter")
            throw CancellationError()
        }
        converter.primeMethod = .none
        input.removeTap(onBus: 0)
        #if DEBUG
        RecitationCapture.shared.begin(sampleRate: Int(analyzerFormat.sampleRate))
        #endif
        nonisolated(unsafe) var tapCount = 0
        nonisolated(unsafe) var droppedCount = 0
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            tapCount += 1
            guard let converted = Self.converted(buffer, with: converter, to: analyzerFormat) else {
                droppedCount += 1
                if droppedCount % 50 == 1 { RecitationTrace.emit("audio", "conversion dropped x\(droppedCount)") }
                return
            }
            if tapCount % 50 == 1 {
                RecitationTrace.emit(
                    "audio",
                    """
                    tap #\(tapCount) frames=\(buffer.frameLength)->\(converted.frameLength) \
                    peak=\(String(format: "%.4f", Self.peak(of: buffer))) dropped=\(droppedCount)
                    """
                )
            }
            #if DEBUG
            RecitationCapture.shared.append(converted)
            #endif
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
        #if DEBUG
        RecitationCapture.shared.finish()
        #endif
        audioEngine.stop()
        let analyzer = analyzer
        self.analyzer = nil
        transcriber = nil
        Task { await analyzer?.cancelAndFinishNow() }
        Self.deactivateAudioSession()
        nextExpectedIndex = nil
        cursorIndex = nil
        heardText = ""
    }

    private nonisolated static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return -1 }
        var highest: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            highest = max(highest, abs(channel[frame]))
        }
        return highest
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
