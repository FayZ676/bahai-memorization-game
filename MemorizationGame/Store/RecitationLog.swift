import Foundation
import Observation

@MainActor
@Observable
final class RecitationLog {
    static let shared = RecitationLog()

    private(set) var attempts: [RecitationAttempt]

    private static let perChunkLimit = 3
    private static let totalLimit = 40

    private let storeURL: URL

    init(filename: String = "recitation-log.json") {
        storeURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([RecitationAttempt].self, from: data) {
            attempts = saved
        } else {
            attempts = []
        }
    }

    func record(_ attempt: RecitationAttempt) {
        attempts.append(attempt)
        prune()
        persist()
    }

    var newestFirst: [RecitationAttempt] { attempts.reversed() }

    static func trace(of attempts: [RecitationAttempt]) -> String {
        guard !attempts.isEmpty else { return "" }
        let stamp = ISO8601DateFormatter()
        return attempts.map { attempt in
            let header = "\(stamp.string(from: attempt.date)) \(attempt.passageTitle) "
                + "chunk \(attempt.chunkID.uuidString.prefix(8)) "
                + "matched \(attempt.matchedCount)/\(attempt.expectedCount)"
            let lines = attempt.misses.map { miss in
                "  [\(miss.wordIndex)] expected \"\(miss.expected)\" (\(miss.expectedKey)) "
                    + "heard \"\(miss.heard)\" (\(miss.heardKeys.joined(separator: " ")))"
            }
            return ([header] + lines + ["  transcript: \(attempt.transcript)"]).joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    private func prune() {
        var kept: [UUID: Int] = [:]
        var survivors: [RecitationAttempt] = []
        for attempt in attempts.reversed() {
            let count = kept[attempt.chunkID, default: 0]
            guard count < Self.perChunkLimit else { continue }
            kept[attempt.chunkID] = count + 1
            survivors.append(attempt)
        }
        attempts = survivors.reversed().suffix(Self.totalLimit).map { $0 }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(attempts) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
