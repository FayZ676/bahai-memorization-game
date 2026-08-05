import Foundation
import Fuse

struct SearchHit: Identifiable, Hashable {
    let prayer: Prayer
    let excerpt: TextExcerpt?

    var id: Int { prayer.id }
}

enum SearchText {
    static func normalized(_ value: String) -> String {
        tokens(value).joined(separator: " ")
    }

    static func tokens(_ value: String) -> [String] {
        WordIndex.tokens(in: value).map(\.text)
    }
}

private struct SearchDocument {
    let title: String
    let tags: String
    let body: String
}

enum FuzzySearch {
    static let resultLimit = 60

    private static let fuse = Fuse(
        location: 0,
        distance: 100,
        threshold: 0.35,
        isCaseSensitive: true,
        tokenize: true
    )

    private static let documents: [SearchDocument] = PrayerLibrary.all.map { prayer in
        SearchDocument(
            title: SearchText.normalized(String(prayer.title.prefix(titleLimit))),
            tags: SearchText.normalized(prayer.tags.joined(separator: " ")),
            body: SearchText.normalized(prayer.text)
        )
    }

    static func prewarm() {
        _ = documents
    }

    nonisolated static func rank(query: String) async -> [SearchHit] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = SearchText.tokens(terms)
        guard !queryTokens.isEmpty else { return [] }
        let normalized = String(queryTokens.joined(separator: " ").prefix(patternLimit))
        guard let pattern = fuse.createPattern(from: normalized) else { return [] }

        var scored: [(index: Int, score: Double, matchedBody: Bool)] = []
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: cancellationStride), Task.isCancelled { return [] }

            let title = relevance(of: pattern, in: document.title)
            let tags = relevance(of: pattern, in: document.tags)
            let body = bodyRelevance(of: queryTokens, in: document.body)

            var score = title * titleWeight + tags * tagWeight + body * bodyWeight
            if contains(normalized, in: document.title) { score += exactTitleBonus }
            if contains(normalized, in: document.tags) { score += exactTagBonus }
            guard score > 0 else { continue }
            scored.append((index, score, body > 0))
        }

        let top = scored
            .sorted { $0.score > $1.score }
            .prefix(resultLimit)

        return top.map { entry in
            let prayer = PrayerLibrary.all[entry.index]
            let excerpt = entry.matchedBody
                ? ExcerptFinder.excerpt(of: terms, in: prayer.text, textID: prayer.id)
                : nil
            return SearchHit(prayer: prayer, excerpt: excerpt)
        }
    }

    private static func contains(_ query: String, in value: String) -> Bool {
        !value.isEmpty && value.range(of: query, options: .literal) != nil
    }

    private static func relevance(of pattern: Fuse.Pattern?, in value: String) -> Double {
        guard !value.isEmpty, let result = fuse.search(pattern, in: value) else { return 0 }
        return 1 - result.score
    }

    private static func bodyRelevance(of queryTokens: [String], in body: String) -> Double {
        guard !body.isEmpty else { return 0 }
        var earliest = Int.max
        for token in queryTokens {
            guard let found = body.range(of: token, options: .literal) else { return 0 }
            earliest = min(earliest, body.utf8.distance(from: body.utf8.startIndex, to: found.lowerBound))
        }
        let depth = min(1, Double(earliest) / Double(prominenceSpan))
        return 1 - depth * depthPenalty
    }

    private static let titleWeight = 1.0
    private static let tagWeight = 0.6
    private static let exactTitleBonus = 0.5
    private static let exactTagBonus = 0.5
    private static let bodyWeight = 0.35
    private static let titleLimit = 120
    private static let patternLimit = 63
    private static let cancellationStride = 64
    private static let prominenceSpan = 2_000
    private static let depthPenalty = 0.3
}
