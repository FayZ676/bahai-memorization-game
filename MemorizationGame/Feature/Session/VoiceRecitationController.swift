import AVFoundation
import Observation
import WhisperKit

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
    var onFrontierAdvance: ((Int) -> Void)?

    private static var cachedWhisper: WhisperKit?
    private var reference: [String] = []
    private var revealedFrontier = -1
    private var tickTask: Task<Void, Never>?

    private let tickInterval: Duration = .milliseconds(400)
    private let sampleRate = 16000
    private let maxBufferSeconds = 28
    private let speechEnergyThreshold: Float = 0.25

    var isListening: Bool { state == .listening }

    func start(reference: [String]) async {
        guard state == .idle || state == .failed || state == .micDenied else { return }
        guard await Self.micPermissionGranted() else {
            state = .micDenied
            return
        }
        state = .preparingModel
        do {
            let whisper = try await Self.loadedWhisper()
            guard state == .preparingModel else { return }
            self.reference = reference
            revealedFrontier = -1
            try Self.activateAudioSession()
            try whisper.audioProcessor.startRecordingLive(callback: nil)
            state = .listening
            beginTicking(whisper)
        } catch {
            state = .failed
            Self.deactivateAudioSession()
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        Self.cachedWhisper?.audioProcessor.stopRecording()
        Self.deactivateAudioSession()
        reference = []
        revealedFrontier = -1
        if state != .micDenied {
            state = .idle
        }
    }

    private func beginTicking(_ whisper: WhisperKit) {
        let promptTokens = whisper.tokenizer.map { $0.encode(text: " " + reference.joined(separator: " ")) }
        tickTask = Task {
            var transcribedSampleCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                guard !Task.isCancelled, state == .listening else { return }
                let samples = Array(whisper.audioProcessor.audioSamples)
                if samples.count > maxBufferSeconds * sampleRate {
                    stop()
                    return
                }
                guard samples.count > transcribedSampleCount + sampleRate / 2 else { continue }
                guard whisper.audioProcessor.relativeEnergy.contains(where: { $0 > speechEnergyThreshold }) else { continue }
                transcribedSampleCount = samples.count
                let options = DecodingOptions(
                    task: .transcribe,
                    language: "en",
                    temperature: 0,
                    usePrefillPrompt: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: true,
                    promptTokens: promptTokens
                )
                let text = (try? await whisper.transcribe(audioArray: samples, decodeOptions: options))?
                    .map(\.text)
                    .joined(separator: " ") ?? ""
                guard !Task.isCancelled, state == .listening else { return }
                advanceFrontier(with: text)
                if revealedFrontier == reference.count - 1 {
                    stop()
                    Feedback.sessionComplete()
                    return
                }
            }
        }
    }

    private func advanceFrontier(with transcript: String) {
        let spoken = transcript.split(separator: " ").map(String.init)
        guard let frontier = RecitationAligner.matchedFrontier(reference: reference, transcript: spoken),
              frontier > revealedFrontier else { return }
        revealedFrontier = frontier
        onFrontierAdvance?(frontier)
    }

    private static func loadedWhisper() async throws -> WhisperKit {
        if let cachedWhisper { return cachedWhisper }
        let whisper = try await WhisperKit(WhisperKitConfig(model: "openai_whisper-tiny.en", verbose: false, logLevel: .error))
        cachedWhisper = whisper
        return whisper
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
        try session.setActive(true)
    }

    private static func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
