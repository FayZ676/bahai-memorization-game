import Foundation
import Fuse

enum FuzzySearch {
    static let resultLimit = 60

    // Bitap cost is linear in the searched text length, so full prayer bodies
    // (up to 250k+ chars) make each query take seconds. Search a capped opening
    // instead — titles/tags/first lines are what people actually search by.
    private static let textSearchLimit = 500

    private struct Indexed: Fuseable {
        let title: String
        let tags: String
        let textPrefix: String

        var properties: [FuseProperty] {
            [
                FuseProperty(name: title, weight: 0.6),
                FuseProperty(name: tags, weight: 0.5),
                FuseProperty(name: textPrefix, weight: 0.4),
            ]
        }
    }

    // Index order must stay aligned with PrayerLibrary.all so result indices map back.
    private static let index: [Indexed] = PrayerLibrary.all.map { prayer in
        Indexed(
            title: prayer.title,
            tags: prayer.tags.joined(separator: " "),
            textPrefix: String(prayer.text.prefix(textSearchLimit))
        )
    }

    private static let fuse = Fuse(
        location: 0,
        distance: textSearchLimit,
        threshold: 0.35,
        maxPatternLength: 63,
        tokenize: true
    )

    static func rank(query: String) async -> [Prayer] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terms.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            fuse.search(terms, in: index) { results in
                let prayers = results.prefix(resultLimit).map { PrayerLibrary.all[$0.index] }
                continuation.resume(returning: prayers)
            }
        }
    }
}
