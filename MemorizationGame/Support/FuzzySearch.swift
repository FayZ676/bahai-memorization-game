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
    let terms: Set<String>
}

enum FuzzySearch {
    static let resultLimit = 60

    private static let fuse = Fuse(
        location: 0,
        distance: 100,
        threshold: phraseThreshold,
        isCaseSensitive: true,
        tokenize: true
    )

    private static let wordFuse = Fuse(
        location: 0,
        distance: 8,
        threshold: termThreshold,
        isCaseSensitive: true
    )

    private static let documents: [SearchDocument] = PrayerLibrary.all.map { prayer in
        let title = SearchText.normalized(String(prayer.title.prefix(titleLimit)))
        let tags = SearchText.normalized(prayer.tags.joined(separator: " "))
        let body = SearchText.normalized(prayer.text)
        return SearchDocument(
            title: title,
            tags: tags,
            body: body,
            terms: Set(title.split(separator: " ").map(String.init))
                .union(tags.split(separator: " ").map(String.init))
                .union(body.split(separator: " ").map(String.init))
        )
    }

    private static let knownTerms: Set<String> = documents.reduce(into: Set<String>()) {
        $0.formUnion($1.terms)
    }

    private static let vocabulary: [String] = Array(knownTerms)

    static func prewarm() {
        _ = vocabulary
    }

    nonisolated static func rank(query: String) async -> [SearchHit] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = SearchText.tokens(terms)
        guard !queryTokens.isEmpty else { return [] }

        let spellings = queryTokens.map(variants(of:))
        let spelledOut = spellings.allSatisfy { !$0.isEmpty }

        let corrected = spellings.compactMap(\.first?.term).joined(separator: " ")
        let normalized = String(queryTokens.joined(separator: " ").prefix(patternLimit))
        let pattern = fuse.createPattern(from: normalized)

        var scored: [(index: Int, score: Double, matchedBody: Bool)] = []
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: cancellationStride), Task.isCancelled { return [] }

            let closeness = termCloseness(of: spellings, in: document)
            if spelledOut && closeness == nil { continue }

            let title = relevance(of: pattern, in: document.title)
            let tags = relevance(of: pattern, in: document.tags)
            let body = (closeness ?? 0) * prominence(of: spellings, in: document.body)

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
                ? ExcerptFinder.excerpt(of: corrected, in: prayer.text, textID: prayer.id)
                : nil
            return SearchHit(prayer: prayer, excerpt: excerpt)
        }
    }

    private struct Spelling {
        let term: String
        let similarity: Double
    }

    private static func variants(of token: String) -> [Spelling] {
        if knownTerms.contains(token) {
            return [Spelling(term: token, similarity: 1)] + neighbours(of: token, excluding: token)
        }
        let swaps = transpositions(of: token)
            .filter(knownTerms.contains)
            .map { Spelling(term: $0, similarity: transposedSimilarity) }
        return swaps + neighbours(of: token, excluding: nil)
    }

    private static func transpositions(of token: String) -> [String] {
        let letters = Array(token)
        guard letters.count > 1 else { return [] }
        return (0..<(letters.count - 1)).map { index in
            var swapped = letters
            swapped.swapAt(index, index + 1)
            return String(swapped)
        }
    }

    private static func neighbours(of token: String, excluding exact: String?) -> [Spelling] {
        guard token.count >= shortestFuzzyTerm, let pattern = wordFuse.createPattern(from: token) else {
            return []
        }
        var found: [Spelling] = []
        for term in vocabulary where term != exact && plausibleLength(term, for: token) {
            guard let result = wordFuse.search(pattern, in: term) else { continue }
            found.append(Spelling(term: term, similarity: 1 - result.score))
        }
        return found
            .sorted { $0.similarity > $1.similarity }
            .prefix(variantLimit)
            .map { $0 }
    }

    private static func plausibleLength(_ term: String, for token: String) -> Bool {
        term.count + maxMissingCharacters >= token.count && term.count <= token.count + maxExtraCharacters
    }

    private static func termCloseness(of spellings: [[Spelling]], in document: SearchDocument) -> Double? {
        var total = 0.0
        for options in spellings {
            guard let best = options.first(where: { document.terms.contains($0.term) }) else {
                return nil
            }
            total += best.similarity
        }
        return total / Double(spellings.count)
    }

    private static func prominence(of spellings: [[Spelling]], in body: String) -> Double {
        guard !body.isEmpty else { return 0 }
        var earliest = Int.max
        for options in spellings {
            guard let match = options.lazy.compactMap({ body.range(of: $0.term, options: .literal) }).first
            else { continue }
            earliest = min(earliest, body.utf8.distance(from: body.utf8.startIndex, to: match.lowerBound))
        }
        guard earliest != Int.max else { return 1 - depthPenalty }
        let depth = min(1, Double(earliest) / Double(prominenceSpan))
        return 1 - depth * depthPenalty
    }

    private static func contains(_ query: String, in value: String) -> Bool {
        !value.isEmpty && value.range(of: query, options: .literal) != nil
    }

    private static func relevance(of pattern: Fuse.Pattern?, in value: String) -> Double {
        guard !value.isEmpty, let result = fuse.search(pattern, in: value) else { return 0 }
        return 1 - result.score
    }

    private static let titleWeight = 1.0
    private static let tagWeight = 0.6
    private static let exactTitleBonus = 0.5
    private static let exactTagBonus = 0.5
    private static let bodyWeight = 0.35
    private static let phraseThreshold = 0.45
    private static let termThreshold = 0.3
    private static let transposedSimilarity = 0.9
    private static let shortestFuzzyTerm = 3
    private static let variantLimit = 6
    private static let maxMissingCharacters = 2
    private static let maxExtraCharacters = 10
    private static let titleLimit = 120
    private static let patternLimit = 63
    private static let cancellationStride = 64
    private static let prominenceSpan = 2_000
    private static let depthPenalty = 0.3
}
