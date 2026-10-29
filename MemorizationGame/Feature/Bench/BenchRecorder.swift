#if DEBUG
import AVFoundation
import Observation

struct BenchTake: Codable {
    let card: String
    let prayer: String
    let words: [String]
    let unsaid: [Int]
    let startIndex: Int?
    let slips: [Int]
    let seconds: Double
    let sampleRate: Double
    let recordedAt: Date
}

@MainActor
@Observable
final class BenchRecorder: NSObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case recording
        case recorded
        case playing
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0

    private let engine = AVAudioEngine()
    private var player: AVAudioPlayer?
    private var draftURL: URL?
    private var startedAt = Date()
    private var clock: Task<Void, Never>?

    nonisolated static let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "Bench")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func savedTakes() -> [BenchTake] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(BenchTake.self, from: Data(contentsOf: $0)) }
    }

    func record() async {
        discard()
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .failed("Microphone permission denied")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let url = Self.directory.appending(path: "draft.wav")
            try? FileManager.default.removeItem(at: url)
            let output = try AVAudioFile(
                forWriting: url,
                settings: Self.format.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
            draftURL = url
            let input = engine.inputNode
            let tapFormat = input.outputFormat(forBus: 0)
            guard let converter = AVAudioConverter(from: tapFormat, to: Self.format) else {
                throw CocoaError(.featureUnsupported)
            }
            converter.primeMethod = .none
            input.removeTap(onBus: 0)
            Self.installTap(on: input, format: tapFormat, converter: converter, writing: output)
            engine.prepare()
            try engine.start()
            startedAt = Date()
            elapsed = 0
            state = .recording
            clock = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard let self, self.state == .recording else { return }
                    self.elapsed = Date().timeIntervalSince(self.startedAt)
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
            stopEngine()
        }
    }

    func stop() {
        switch state {
        case .recording:
            elapsed = Date().timeIntervalSince(startedAt)
            stopEngine()
            state = .recorded
        case .playing:
            player?.stop()
            state = .recorded
        default:
            break
        }
    }

    func play() {
        guard let draftURL, state == .recorded else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: draftURL)
            player.delegate = self
            player.play()
            self.player = player
            state = .playing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.state == .playing { self.state = .recorded }
        }
    }

    func save(_ take: BenchTake) throws {
        guard let draftURL else { return }
        player?.stop()
        player = nil
        let stamp = ISO8601DateFormatter().string(from: take.recordedAt).replacingOccurrences(of: ":", with: "-")
        let stem = "bench-\(take.card)-\(stamp)"
        try FileManager.default.moveItem(at: draftURL, to: Self.directory.appending(path: "\(stem).wav"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(take).write(to: Self.directory.appending(path: "\(stem).json"))
        self.draftURL = nil
        state = .idle
        elapsed = 0
    }

    func discard() {
        stopEngine()
        player?.stop()
        player = nil
        if let draftURL { try? FileManager.default.removeItem(at: draftURL) }
        draftURL = nil
        state = .idle
        elapsed = 0
    }

    private func stopEngine() {
        clock?.cancel()
        clock = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private nonisolated static func installTap(
        on input: AVAudioInputNode,
        format tapFormat: AVAudioFormat,
        converter: AVAudioConverter,
        writing output: AVAudioFile
    ) {
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            guard let converted = convert(buffer, with: converter) else { return }
            try? output.write(from: converted)
        }
    }

    private nonisolated static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var pending: AVAudioPCMBuffer? = buffer
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            guard let next = pending else {
                status.pointee = .noDataNow
                return nil
            }
            pending = nil
            status.pointee = .haveData
            return next
        }
        return error == nil ? output : nil
    }
}
#endif
