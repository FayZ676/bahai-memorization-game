import AVFoundation
import CoreML
import Foundation

final class ConformerRecitation: @unchecked Sendable {
    static let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(ConformerTracker.sampleRate),
        channels: 1,
        interleaved: false
    )!

    private struct Loaded: @unchecked Sendable {
        let model: MLModel
        let tokenizer: ConformerTokenizer
    }

    @MainActor private static var loading: Task<Loaded, Error>?

    @MainActor static func preload() {
        guard loading == nil else { return }
        loading = Task.detached(priority: .userInitiated) {
            guard let modelURL = Bundle.main.url(forResource: "Conformer", withExtension: "mlmodelc"),
                  let vocabularyURL = Bundle.main.url(forResource: "conformer-vocabulary", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let vocabulary = try JSONDecoder().decode(ConformerVocabulary.self, from: Data(contentsOf: vocabularyURL))
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let clock = ContinuousClock.now
            let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
            RecitationTrace.emit("conformer", "model loaded in \(ContinuousClock.now - clock)")
            return Loaded(model: model, tokenizer: ConformerTokenizer(vocabulary))
        }
    }

    @MainActor static func make(
        words: [String],
        hidden: [Int],
        start: Int = 0,
        onCredits: @escaping @MainActor ([Int]) -> Void,
        onFlash: @escaping @MainActor (Int) -> Void = { _ in }
    ) async throws -> ConformerRecitation {
        preload()
        guard let loading else { throw CancellationError() }
        do {
            let loaded = try await loading.value
            return ConformerRecitation(
                loaded: loaded,
                words: words,
                hidden: hidden,
                start: start,
                onCredits: onCredits,
                onFlash: onFlash
            )
        } catch {
            Self.loading = nil
            throw error
        }
    }

    private let model: MLModel
    private let onCredits: @MainActor ([Int]) -> Void
    private let onFlash: @MainActor (Int) -> Void
    private let queue = DispatchQueue(label: "conformer-recitation", qos: .userInitiated)
    private let input: MLMultiArray
    private var session: ConformerSession
    private var samples: [Float] = []
    private var nextHop = ConformerTracker.hopSamples
    private var finished = false
    private var hopDurations: [Duration] = []

    private init(
        loaded: Loaded,
        words: [String],
        hidden: [Int],
        start: Int,
        onCredits: @escaping @MainActor ([Int]) -> Void,
        onFlash: @escaping @MainActor (Int) -> Void
    ) {
        model = loaded.model
        self.onCredits = onCredits
        self.onFlash = onFlash
        session = ConformerSession(
            words: words,
            hidden: Set(hidden),
            start: start,
            tokenizer: loaded.tokenizer,
            classes: loaded.tokenizer.blank + 1
        )
        input = try! MLMultiArray(shape: [1, NSNumber(value: ConformerTracker.windowSamples)], dataType: .float32)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        queue.async { [self] in
            guard !finished else { return }
            samples.append(contentsOf: chunk)
            while samples.count >= nextHop {
                let end = nextHop
                nextHop += ConformerTracker.hopSamples
                hop(end: end, done: false)
            }
        }
    }

    func updateHidden(_ hidden: [Int]) {
        queue.async { [self] in session.setHidden(Set(hidden)) }
    }

    func finish() {
        queue.async { [self] in
            guard !finished else { return }
            finished = true
            guard !samples.isEmpty else { return }
            hop(end: samples.count + ConformerTracker.lookaheadSamples, done: true)
        }
    }

    func drained() async -> [Duration] {
        await withCheckedContinuation { continuation in
            queue.async { [self] in continuation.resume(returning: hopDurations) }
        }
    }

    private func hop(end: Int, done: Bool) {
        let clock = ContinuousClock.now
        let update = samples.withUnsafeBufferPointer { audio in
            session.listen(through: end, audio: audio, done: done, predict: predict)
        }
        hopDurations.append(ContinuousClock.now - clock)
        RecitationTrace.emit(
            "conformer",
            "hop end=\(end) done=\(done) took=\(ContinuousClock.now - clock) credited=\(update.credits) flashed=\(update.flashed.map(String.init) ?? "-")"
        )
        let indices = update.credits
        if !indices.isEmpty { Task { @MainActor in onCredits(indices) } }
        if let flashed = update.flashed { Task { @MainActor in onFlash(flashed) } }
    }

    private func predict(_ chunk: UnsafeBufferPointer<Float>) -> [Float]? {
        input.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
            for offset in 0..<min(buffer.count, chunk.count) { buffer[offset] = chunk[offset] }
        }
        guard let prediction = try? model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": input])),
              let logProbs = prediction.featureValue(for: "log_probs")?.multiArrayValue else {
            RecitationTrace.emit("conformer", "prediction failed")
            return nil
        }
        return MLShapedArray<Float>(converting: logProbs).scalars
    }
}
