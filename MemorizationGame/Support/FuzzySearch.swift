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
    let labels: String
    let body: String
    let terms: Set<String>
    let pairs: Set<String>
    let fragments: Set<String>
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
        let labels = SearchText.normalized(
            ([prayer.collection, prayer.section, prayer.author] + prayer.tags).joined(separator: " ")
        )
        let body = SearchText.normalized(prayer.text)
        let words = (title + " " + labels + " " + body).split(separator: " ").map(String.init)
        return SearchDocument(
            title: title,
            labels: labels,
            body: body,
            terms: Set(words),
            pairs: Set(zip(words, words.dropFirst()).map { $0 + " " + $1 }),
            fragments: fragments(of: title + " " + labels, length: fragmentLength)
        )
    }

    private static let knownTerms: Set<String> = documents.reduce(into: Set<String>()) {
        $0.formUnion($1.terms)
    }

    private static let termsBySpellingKey: [String: [String]] = {
        var index: [String: [String]] = [:]
        for term in knownTerms {
            for key in fragments(of: term, length: spellingKeyLength) {
                index[key, default: []].append(term)
            }
        }
        return index
    }()

    static func prewarm() {
        _ = termsBySpellingKey
    }

    nonisolated static func rank(query: String) async -> [SearchHit] {
        let queryTokens = SearchText.tokens(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !queryTokens.isEmpty else { return [] }

        let spellings = queryTokens.map(variants(of:))
        let corrected = zip(queryTokens, spellings)
            .map { token, options in options.first?.term ?? token }
            .joined(separator: " ")
        let queryCarriesMeaning = queryTokens.contains(where: WordIndex.carriesMeaning)
        let weights = queryTokens.map { WordIndex.carriesMeaning($0) ? 1.0 : connectiveWeight }
        let normalized = String(queryTokens.joined(separator: " ").prefix(patternLimit))
        let queryFragments = fragments(of: normalized, length: fragmentLength)
        let pattern = fuse.createPattern(from: normalized)

        var scored: [(index: Int, score: Double, matchedBody: Bool)] = []
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: cancellationStride), Task.isCancelled { return [] }

            let found = matches(of: spellings, in: document)
            let coverage = coverage(of: found, weights: weights)
            let anchors = found.compactMap { $0 }
                .filter { !queryCarriesMeaning || WordIndex.carriesMeaning($0.term) }
            guard !anchors.isEmpty || !document.fragments.isDisjoint(with: queryFragments) else { continue }

            let title = relevance(of: pattern, in: document.title)
            let labels = relevance(of: pattern, in: document.labels)
            let placement = anchors.isEmpty ? nil : placement(of: anchors, in: document.body)
            let body = coverage * (placement?.prominence ?? 0)
            let phrase = adjacency(of: spellings, in: document)

            var score = title * titleWeight
                + labels * labelWeight
                + body * bodyWeight
                + phrase * phraseWeight
            if contains(normalized, in: document.title) { score += exactTitleBonus }
            if contains(normalized, in: document.labels) { score += exactLabelBonus }
            score *= pow(max(coverage, faintCoverage), coverageExponent)
            guard score > 0 else { continue }
            scored.append((index, score, placement?.inBody == true))
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

    private struct Placement {
        let prominence: Double
        let inBody: Bool
    }

    private static func variants(of token: String) -> [Spelling] {
        if knownTerms.contains(token) {
            let exact = Spelling(term: token, similarity: 1)
            guard WordIndex.carriesMeaning(token) else { return [exact] }
            return [exact] + neighbours(of: token, excluding: token)
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

        var candidates: Set<String> = []
        for key in fragments(of: token, length: spellingKeyLength) {
            candidates.formUnion(termsBySpellingKey[key] ?? [])
        }

        var found: [Spelling] = []
        for term in candidates where term != exact && plausibleLength(term, for: token) {
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

    private static func fragments(of value: String, length: Int) -> Set<String> {
        var found: Set<String> = []
        for word in value.split(separator: " ") {
            let letters = Array(word)
            guard letters.count > length else {
                found.insert(String(letters))
                continue
            }
            for start in 0...(letters.count - length) {
                found.insert(String(letters[start..<(start + length)]))
            }
        }
        return found
    }

    private static func matches(of spellings: [[Spelling]], in document: SearchDocument) -> [Spelling?] {
        spellings.map { options in options.first { document.terms.contains($0.term) } }
    }

    private static func coverage(of found: [Spelling?], weights: [Double]) -> Double {
        var total = 0.0
        var possible = 0.0
        for (match, weight) in zip(found, weights) {
            possible += weight
            total += (match?.similarity ?? 0) * weight
        }
        guard possible > 0 else { return 0 }
        return total / possible
    }

    private static func adjacency(of spellings: [[Spelling]], in document: SearchDocument) -> Double {
        guard spellings.count > 1 else { return 0 }
        var joined = 0
        for offset in 0..<(spellings.count - 1) {
            let leading = spellings[offset].prefix(pairVariantLimit)
            let trailing = spellings[offset + 1].prefix(pairVariantLimit)
            let linked = leading.contains { first in
                trailing.contains { document.pairs.contains(first.term + " " + $0.term) }
            }
            if linked { joined += 1 }
        }
        return Double(joined) / Double(spellings.count - 1)
    }

    private static func placement(of anchors: [Spelling], in body: String) -> Placement? {
        guard !body.isEmpty else { return nil }
        var earliest = Int.max
        var meaningful = false
        for match in anchors {
            guard let range = body.range(of: match.term, options: .literal) else { continue }
            if WordIndex.carriesMeaning(match.term) { meaningful = true }
            earliest = min(earliest, body.utf8.distance(from: body.utf8.startIndex, to: range.lowerBound))
        }
        guard earliest != Int.max else { return Placement(prominence: 1 - depthPenalty, inBody: false) }
        let depth = min(1, Double(earliest) / Double(prominenceSpan))
        return Placement(prominence: 1 - depth * depthPenalty, inBody: meaningful)
    }

    private static func contains(_ query: String, in value: String) -> Bool {
        !value.isEmpty && value.range(of: query, options: .literal) != nil
    }

    private static func relevance(of pattern: Fuse.Pattern?, in value: String) -> Double {
        guard !value.isEmpty, let result = fuse.search(pattern, in: value) else { return 0 }
        return 1 - result.score
    }

    private static let titleWeight = 1.0
    private static let labelWeight = 0.6
    private static let bodyWeight = 0.35
    private static let phraseWeight = 0.5
    private static let exactTitleBonus = 0.5
    private static let exactLabelBonus = 0.5
    private static let connectiveWeight = 0.35
    private static let coverageExponent = 1.5
    private static let faintCoverage = 0.08
    private static let fragmentLength = 3
    private static let spellingKeyLength = 2
    private static let phraseThreshold = 0.45
    private static let termThreshold = 0.3
    private static let transposedSimilarity = 0.9
    private static let shortestFuzzyTerm = 3
    private static let variantLimit = 6
    private static let pairVariantLimit = 3
    private static let maxMissingCharacters = 2
    private static let maxExtraCharacters = 10
    private static let titleLimit = 120
    private static let patternLimit = 63
    private static let cancellationStride = 64
    private static let prominenceSpan = 2_000
    private static let depthPenalty = 0.3
}
