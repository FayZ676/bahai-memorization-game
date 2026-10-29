#if DEBUG
import AVFoundation
import Foundation

@MainActor
enum BenchLive {
    struct Result: Encodable {
        let credited: [Int]
        let hopMillis: [Double]
    }

    static func run() async {
        let takes = ((try? FileManager.default.contentsOfDirectory(at: BenchRecorder.directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "wav" && $0.lastPathComponent.hasPrefix("bench-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for wav in takes {
            let stem = wav.deletingPathExtension()
            guard let take = try? decoder.decode(BenchTake.self, from: Data(contentsOf: stem.appendingPathExtension("json"))) else { continue }
            var credited: [Int] = []
            do {
                let engine = try await ConformerRecitation.make(
                    words: take.words,
                    hidden: Array(take.words.indices),
                    start: take.startIndex ?? 0,
                    onCredits: { credited.append(contentsOf: $0) }
                )
                let file = try AVAudioFile(forReading: wav)
                while file.framePosition < file.length {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: ConformerRecitation.format, frameCapacity: 1024) else { break }
                    try file.read(into: buffer, frameCount: 1024)
                    engine.append(buffer)
                }
                engine.finish()
                let durations = await engine.drained()
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(100))
                let millis = durations.map { Double($0.components.attoseconds) / 1e15 + Double($0.components.seconds) * 1000 }
                try encoder.encode(Result(credited: credited.sorted(), hopMillis: millis))
                    .write(to: stem.appendingPathExtension("live.json"))
                let sorted = millis.sorted()
                print("bench-live \(stem.lastPathComponent) credited=\(credited.count) hops=\(millis.count) median=\(Int(sorted[sorted.count / 2])) ms max=\(Int(sorted.last ?? 0)) ms")
            } catch {
                print("bench-live failed \(stem.lastPathComponent): \(error)")
                return
            }
        }
        print("bench-live finished")
    }
}
#endif
