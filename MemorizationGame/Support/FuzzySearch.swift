import Foundation
import Fuse

extension Prayer: Fuseable {
    public var properties: [FuseProperty] {
        [
            FuseProperty(name: title, weight: 0.6),
            FuseProperty(name: tags.joined(separator: " "), weight: 0.5),
            FuseProperty(name: text, weight: 0.4),
        ]
    }
}

enum FuzzySearch {
    static let resultLimit = 60

    private static let fuse = Fuse(
        location: 0,
        distance: 1_000_000,
        threshold: 0.35,
        maxPatternLength: 63,
        tokenize: true
    )

    static func rank(query: String) async -> [Prayer] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terms.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            fuse.search(terms, in: PrayerLibrary.all) { results in
                let prayers = results.prefix(resultLimit).map { PrayerLibrary.all[$0.index] }
                continuation.resume(returning: prayers)
            }
        }
    }
}
