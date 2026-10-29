#if DEBUG
import AVFoundation
import CoreML
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class BenchConformer {
    private(set) var progress = ""
    private(set) var isRunning = false

    nonisolated static let windowSamples = 96_000
    nonisolated static let hopSamples = 16_000
    nonisolated static let lookaheadSamples = 8_000
    nonisolated static let samplesPerFrame = 640

    struct Report: Encodable {
        let model: String
        let computeUnits: String
        let windows: Int
        let frames: Int
        let classes: Int
        let starts: [Int]
        let strides: [Int]
        let dataType: Int
        let millis: [Double]
        let loadMillis: Double
    }

    var models: [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: BenchRecorder.directory, includingPropertiesForKeys: nil)) ?? []
        let candidates = urls.filter { $0.pathExtension == "mlmodelc" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return [Bundle.main.url(forResource: "Conformer", withExtension: "mlmodelc")].compactMap { $0 } + candidates
    }

    var takes: [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: BenchRecorder.directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "wav" && $0.lastPathComponent.hasPrefix("bench-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            isRunning = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        let takes = takes
        for modelURL in models {
            let name = modelURL.deletingPathExtension().lastPathComponent
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let loadStart = ContinuousClock.now
            guard let model = try? await MLModel.load(contentsOf: modelURL, configuration: configuration) else {
                progress = "Could not load \(name)"
                print("bench-conformer load failed \(name)")
                return
            }
            let loadMillis = Self.millis(since: loadStart)
            print("bench-conformer loaded \(name) in \(Int(loadMillis)) ms")
            for (index, wav) in takes.enumerated() {
                let stem = wav.deletingPathExtension().lastPathComponent
                progress = "\(name) \(index + 1)/\(takes.count) \(stem)"
                do {
                    let report = try await Task.detached { try Self.replay(wav, through: model, name: name, loadMillis: loadMillis) }.value
                    let sorted = report.millis.sorted()
                    print("bench-conformer \(name) \(stem) windows=\(report.windows) median=\(Int(sorted[sorted.count / 2])) ms max=\(Int(sorted.last ?? 0)) ms")
                } catch {
                    progress = "Failed on \(stem): \(error.localizedDescription)"
                    print("bench-conformer failed \(stem): \(error)")
                    return
                }
                await Task.yield()
            }
        }
        progress = "Done — \(models.count) models × \(takes.count) takes"
    }

    private nonisolated static func replay(_ wav: URL, through model: MLModel, name: String, loadMillis: Double) throws -> Report {
        let audio = try samples(in: wav)
        let input = try MLMultiArray(shape: [1, NSNumber(value: windowSamples)], dataType: .float32)
        var output = Data()
        var starts: [Int] = []
        var millis: [Double] = []
        var frames = 0
        var classes = 0
        var strides: [Int] = []
        var dataType = 0
        var heard = 0
        while true {
            heard += hopSamples
            let end = min(heard, audio.count + lookaheadSamples)
            let start = max(0, end - windowSamples) / samplesPerFrame * samplesPerFrame
            let available = max(0, min(end, audio.count) - start)
            input.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
                buffer.initialize(repeating: 0)
                audio.withUnsafeBufferPointer { source in
                    for offset in 0..<available { buffer[offset] = source[start + offset] }
                }
            }
            let clock = ContinuousClock.now
            let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": input]))
            millis.append(Self.millis(since: clock))
            guard let logProbs = prediction.featureValue(for: "log_probs")?.multiArrayValue else {
                throw CocoaError(.coderValueNotFound)
            }
            frames = logProbs.shape[1].intValue
            classes = logProbs.shape[2].intValue
            strides = logProbs.strides.map(\.intValue)
            dataType = logProbs.dataType.rawValue
            output.append(halfPrecision(logProbs))
            starts.append(start)
            if heard >= audio.count + lookaheadSamples { break }
        }
        let stem = wav.deletingPathExtension()
        try output.write(to: stem.appendingPathExtension("\(name).f16"))
        let report = Report(
            model: name,
            computeUnits: "all",
            windows: starts.count,
            frames: frames,
            classes: classes,
            starts: starts,
            strides: strides,
            dataType: dataType,
            millis: millis,
            loadMillis: loadMillis
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: stem.appendingPathExtension("\(name).json"))
        return report
    }

    private nonisolated static func samples(in wav: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: wav)
        guard file.processingFormat.sampleRate == 16_000,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?[0] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    private nonisolated static func halfPrecision(_ array: MLMultiArray) -> Data {
        let values = MLShapedArray<Float>(converting: array).scalars.map(Float16.init)
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private nonisolated static func millis(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    }
}
#endif
