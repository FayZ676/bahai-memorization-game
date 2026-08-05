import Foundation

struct TextExcerpt: Hashable {
    let snippet: String
    let highlightInSnippet: Range<Int>
    let rangeInText: Range<Int>
}

enum ExcerptFinder {
    static func excerpt(of query: String, in text: String, textID: Int? = nil) -> TextExcerpt? {
        let words = textID.map { WordIndexCache.index(for: text, id: $0) } ?? WordIndex(text)
        guard let match = locate(query: query, in: words) else { return nil }
        return snippet(around: match, in: Array(text))
    }

    private static func locate(query: String, in words: WordIndex) -> Range<Int>? {
        let terms = WordIndex.tokens(in: query).map(\.text)
        guard !terms.isEmpty else { return nil }

        if terms.count == 1 {
            guard WordIndex.carriesMeaning(terms[0]),
                  let hit = words.positions(of: terms[0]).first else { return nil }
            return words.sourceRange(ofWords: hit...hit)
        }

        let run = words.longestRun(of: terms)
        let window = words.tightestWindow(covering: terms)
        let strongest = [run, window].compactMap { $0 }.max { $0.terms < $1.terms }

        let chosen: WordIndex.Match?
        if let strongest, strongest.terms >= 2 {
            chosen = strongest
        } else {
            chosen = words.rarestTerm(among: terms) ?? strongest
        }
        guard let chosen else { return nil }
        return words.sourceRange(ofWords: chosen.range)
    }

    private static func snippet(around match: Range<Int>, in characters: [Character]) -> TextExcerpt {
        let start = boundary(before: match.lowerBound, in: characters)
        let end = boundary(after: match.upperBound, in: characters)

        var snippet = String(characters[start..<end]).replacingOccurrences(of: "\n", with: " ")
        var highlightStart = match.lowerBound - start
        if start > 0 {
            snippet = "…" + snippet
            highlightStart += 1
        }
        if end < characters.count {
            snippet += "…"
        }

        let highlightEnd = min(highlightStart + match.count, snippet.count)
        return TextExcerpt(
            snippet: snippet,
            highlightInSnippet: highlightStart..<max(highlightStart, highlightEnd),
            rangeInText: match
        )
    }

    private static func boundary(before index: Int, in characters: [Character]) -> Int {
        let floor = max(0, index - leadingContext)
        var cursor = index
        while cursor > floor {
            if isSentenceEnd(characters[cursor - 1]) { return skippingSpace(from: cursor, in: characters) }
            cursor -= 1
        }
        guard floor > 0 else { return 0 }
        var wordStart = floor
        while wordStart < index && !characters[wordStart].isWhitespace { wordStart += 1 }
        return skippingSpace(from: wordStart, in: characters)
    }

    private static func boundary(after index: Int, in characters: [Character]) -> Int {
        let ceiling = min(characters.count, index + trailingContext)
        var cursor = index
        while cursor < ceiling {
            if isSentenceEnd(characters[cursor]) { return cursor + 1 }
            cursor += 1
        }
        guard ceiling < characters.count else { return characters.count }
        var wordEnd = ceiling
        while wordEnd > index && !characters[wordEnd - 1].isWhitespace { wordEnd -= 1 }
        return wordEnd
    }

    private static func skippingSpace(from index: Int, in characters: [Character]) -> Int {
        var cursor = index
        while cursor < characters.count && characters[cursor].isWhitespace { cursor += 1 }
        return cursor
    }

    private static func isSentenceEnd(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == "\n"
    }

    private static let leadingContext = 110
    private static let trailingContext = 190
}

struct WordIndex {
    struct Word {
        let text: String
        let start: Int
        let end: Int
    }

    struct Match {
        let range: ClosedRange<Int>
        let terms: Int
    }

    let words: [Word]
    private let positionsByWord: [String: [Int]]

    init(_ text: String) {
        let words = Self.tokens(in: text)
        var positions: [String: [Int]] = [:]
        for (position, word) in words.enumerated() {
            positions[word.text, default: []].append(position)
        }
        self.words = words
        self.positionsByWord = positions
    }

    func positions(of term: String) -> [Int] {
        positionsByWord[term] ?? []
    }

    func sourceRange(ofWords range: ClosedRange<Int>) -> Range<Int>? {
        guard range.lowerBound >= 0, range.upperBound < words.count else { return nil }
        return words[range.lowerBound].start..<words[range.upperBound].end
    }

    func longestRun(of terms: [String]) -> Match? {
        guard terms.count >= 2 else { return nil }

        var candidates: [[String]] = []
        for length in stride(from: terms.count, through: 2, by: -1) {
            for offset in 0...(terms.count - length) {
                candidates.append(Array(terms[offset..<(offset + length)]))
            }
        }

        let ranked = candidates
            .filter(Self.saysSomething)
            .sorted { left, right in
                let leftWeight = left.filter(Self.carriesMeaning).count
                let rightWeight = right.filter(Self.carriesMeaning).count
                if leftWeight != rightWeight { return leftWeight > rightWeight }
                return left.count > right.count
            }

        for run in ranked {
            if let start = firstRun(of: run) {
                return Match(
                    range: start...(start + run.count - 1),
                    terms: run.filter(Self.carriesMeaning).count
                )
            }
        }
        return nil
    }

    func tightestWindow(covering terms: [String]) -> Match? {
        let meaningfulTerms = Set(terms.filter(Self.carriesMeaning))
        guard meaningfulTerms.count >= 2 else { return nil }

        var hits: [(position: Int, term: String)] = []
        for term in meaningfulTerms {
            for position in positions(of: term).prefix(occurrenceLimit) {
                hits.append((position, term))
            }
        }
        guard hits.count > 1 else { return nil }
        hits.sort { $0.position < $1.position }

        var counts: [String: Int] = [:]
        var best: ClosedRange<Int>?
        var bestScore = 0
        var low = 0
        for high in hits.indices {
            counts[hits[high].term, default: 0] += 1
            while hits[high].position - hits[low].position > windowWords {
                counts[hits[low].term]! -= 1
                if counts[hits[low].term] == 0 { counts[hits[low].term] = nil }
                low += 1
            }
            let distinct = counts.count
            if distinct > bestScore {
                bestScore = distinct
                best = hits[low].position...hits[high].position
            }
        }

        guard bestScore >= 2, let best else { return nil }
        return Match(range: best, terms: bestScore)
    }

    func rarestTerm(among terms: [String]) -> Match? {
        let present = Set(terms.filter(Self.carriesMeaning))
            .map { (term: $0, hits: positions(of: $0)) }
            .filter { !$0.hits.isEmpty && $0.hits.count <= rareOccurrences }
        guard let rarest = present.min(by: { $0.hits.count < $1.hits.count }),
              let first = rarest.hits.first else { return nil }
        return Match(range: first...first, terms: 1)
    }

    private func firstRun(of run: [String]) -> Int? {
        guard let first = run.first else { return nil }
        for start in positions(of: first) {
            guard start + run.count <= words.count else { break }
            var offset = 1
            while offset < run.count && words[start + offset].text == run[offset] { offset += 1 }
            if offset == run.count { return start }
        }
        return nil
    }

    static func tokens(in text: String) -> [Word] {
        var words: [Word] = []
        var current = ""
        var start = 0

        func flush(_ end: Int) {
            guard !current.isEmpty else { return }
            words.append(Word(text: current, start: start, end: end))
            current = ""
        }

        for (offset, character) in text.enumerated() {
            if character.isLetter || character.isNumber {
                if current.isEmpty { start = offset }
                current.append(contentsOf: fold(character))
            } else if apostrophes.contains(character) && !current.isEmpty {
                continue
            } else {
                flush(offset)
            }
        }
        flush(text.count)
        return words
    }

    private static func fold(_ character: Character) -> [Character] {
        if let ascii = character.asciiValue {
            return ascii >= 65 && ascii <= 90 ? [Character(UnicodeScalar(ascii + 32))] : [character]
        }
        return Array(
            String(character).folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: nil
            )
        )
    }

    static func saysSomething(_ run: [String]) -> Bool {
        let meaningful = run.filter(carriesMeaning).count
        return meaningful >= 2 || (meaningful == 1 && run.count >= 3)
    }

    static func carriesMeaning(_ term: String) -> Bool {
        term.count > 2 && !connectives.contains(term)
    }

    private static let connectives: Set<String> = [
        "the", "and", "but", "for", "not", "all", "any", "are", "was", "who", "you", "our",
        "its", "his", "her", "him", "one", "out", "own", "may", "can", "has", "had", "did",
        "that", "this", "with", "from", "unto", "into", "upon", "they", "them", "their",
        "have", "hath", "been", "were", "shall", "will", "which", "what", "when", "then",
        "than", "thou", "thee", "thy", "your", "yours", "there", "here", "such", "some",
        "every", "each", "also", "very", "more", "most", "doth", "hast", "whom", "would"
    ]

    private static let apostrophes: Set<Character> = ["’", "‘", "ʻ", "ʼ", "'", "`", "´"]

    private let rareOccurrences = 3
    private let occurrenceLimit = 400
    private let windowWords = 24
}

private enum WordIndexCache {
    static func index(for text: String, id: Int) -> WordIndex {
        lock.lock()
        if let cached = entries[id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let built = WordIndex(text)
        lock.lock()
        if entries.count >= capacity { entries.removeAll(keepingCapacity: true) }
        entries[id] = built
        lock.unlock()
        return built
    }

    nonisolated(unsafe) private static var entries: [Int: WordIndex] = [:]
    private static let lock = NSLock()
    private static let capacity = 80
}
