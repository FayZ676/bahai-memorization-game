import Foundation

struct RecitationMatcher {
    enum Event: Equatable {
        case matched(index: Int)
        case missed(index: Int, movedOn: Bool)
    }

    private let words: [String]
    private let compoundRun: [Range<Int>]
    private let compoundText: [String]
    private var hiddenIndices: [Int]
    private var queuePosition = 0
    private var failedAttempts = 0
    private var segmentMatchConsumed = 0
    private var normalizedCache: [String: String] = [:]

    init(words: [String], hiddenIndices: [Int]) {
        let normalized = words.map(Self.normalize)
        let runs = Self.compoundRuns(in: words)
        self.words = normalized
        compoundRun = runs
        compoundText = runs.map { run in
            run.count > 1 ? run.map { normalized[$0] }.joined() : ""
        }
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < normalized.count }.sorted()
    }

    var isComplete: Bool { queuePosition >= hiddenIndices.count }
    var nextExpectedIndex: Int? { isComplete ? nil : hiddenIndices[queuePosition] }

    mutating func replaceHidden(with indices: [Int]) {
        let frontier = nextExpectedIndex ?? words.count
        hiddenIndices = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        queuePosition = hiddenIndices.firstIndex { $0 >= frontier } ?? hiddenIndices.count
        failedAttempts = 0
    }

    mutating func updateVolatile(_ segmentTokens: [String]) -> [Event] {
        scan(segmentTokens, alternatives: [], commitMisses: false)
    }

    mutating func finalizeSegment(
        _ segmentTokens: [String],
        alternatives: [[String]] = []
    ) -> [Event] {
        let events = scan(segmentTokens, alternatives: alternatives, commitMisses: true)
        segmentMatchConsumed = 0
        return events
    }

    private mutating func normalized(_ token: String) -> String {
        if let cached = normalizedCache[token] { return cached }
        let value = Self.normalize(token)
        normalizedCache[token] = value
        return value
    }

    private mutating func normalizedTokens(_ raw: [String]) -> [String] {
        var tokens: [String] = []
        tokens.reserveCapacity(raw.count)
        for token in raw {
            let normalized = normalized(token)
            if !normalized.isEmpty { tokens.append(normalized) }
        }
        return tokens
    }

    private mutating func scan(
        _ segmentTokens: [String],
        alternatives: [[String]],
        commitMisses: Bool
    ) -> [Event] {
        let tokens = normalizedTokens(segmentTokens)
        let alternates = alternatives.map { normalizedTokens($0) }
        var events: [Event] = []
        var position = min(segmentMatchConsumed, tokens.count)
        while position < tokens.count, let expected = nextExpectedIndex {
            let token = tokens[position]
            defer { position += 1 }
            if let matched = consume(token, expected: expected) {
                events.append(contentsOf: matched)
                segmentMatchConsumed = position + 1
                continue
            }
            if let matched = consumeAlternate(at: position, in: alternates, expected: expected) {
                events.append(contentsOf: matched)
                segmentMatchConsumed = position + 1
                continue
            }
            if isIgnorableContext(token, before: expected) || !commitMisses {
                continue
            }
            if let nextHidden = upcomingHiddenIndex, Self.tokensMatch(token, words[nextHidden]) {
                events.append(.missed(index: expected, movedOn: true))
                advance()
                events.append(.matched(index: nextHidden))
                advance()
            } else if matchesSkipWindow(token, after: expected) {
                events.append(.missed(index: expected, movedOn: true))
                advance()
            } else {
                failedAttempts += 1
                if failedAttempts >= 3 {
                    events.append(.missed(index: expected, movedOn: true))
                    advance()
                } else {
                    events.append(.missed(index: expected, movedOn: false))
                }
            }
            segmentMatchConsumed = position + 1
        }
        return events
    }

    private mutating func consume(_ token: String, expected: Int) -> [Event]? {
        if Self.tokensMatch(token, words[expected]) {
            defer { advance() }
            return [.matched(index: expected)]
        }
        let joined = compoundText[expected]
        guard !joined.isEmpty, Self.tokensMatch(token, joined) else { return nil }
        let run = compoundRun[expected]
        var events: [Event] = []
        while let next = nextExpectedIndex, next < run.upperBound {
            events.append(.matched(index: next))
            advance()
        }
        return events
    }

    private mutating func consumeAlternate(
        at position: Int,
        in alternates: [[String]],
        expected: Int
    ) -> [Event]? {
        for alternate in alternates {
            for offset in -1...1 {
                let index = position + offset
                guard index >= 0, index < alternate.count else { continue }
                if let matched = consume(alternate[index], expected: expected) { return matched }
            }
        }
        return nil
    }

    private mutating func advance() {
        queuePosition += 1
        failedAttempts = 0
    }

    private var upcomingHiddenIndex: Int? {
        queuePosition + 1 < hiddenIndices.count ? hiddenIndices[queuePosition + 1] : nil
    }

    private func isIgnorableContext(_ token: String, before expected: Int) -> Bool {
        let previousHidden = queuePosition > 0 ? hiddenIndices[queuePosition - 1] : 0
        let start = min(previousHidden, max(0, expected - 6))
        return words[start..<expected].contains { Self.tokensMatch(token, $0) }
    }

    private func matchesSkipWindow(_ token: String, after expected: Int) -> Bool {
        let upper = min(expected + 2, words.count - 1)
        guard upper > expected else { return false }
        return ((expected + 1)...upper).contains { Self.tokensMatch(token, words[$0]) }
    }

    private static func compoundRuns(in words: [String]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        runs.reserveCapacity(words.count)
        var start = 0
        for index in words.indices where index > start && !words[index].hasPrefix("-") {
            let run = start..<index
            runs.append(contentsOf: repeatElement(run, count: run.count))
            start = index
        }
        let tail = start..<words.count
        runs.append(contentsOf: repeatElement(tail, count: tail.count))
        return runs
    }

    static let spokenEquivalents: [String: String] = [
        "oh": "o",
    ]

    static let numeralEquivalents: [String: String] = [
        "1": "one",
        "2": "two",
        "3": "three",
        "4": "four",
        "5": "five",
        "6": "six",
        "7": "seven",
        "8": "eight",
        "9": "nine",
        "10": "ten",
        "100": "hundred",
        "1000": "thousand",
        "1st": "first",
        "2nd": "second",
        "3rd": "third",
    ]

    private static let foldingLocale = Locale(identifier: "en_US")

    static func normalize(_ token: some StringProtocol) -> String {
        let alphanumeric = token.lowercased().filter { $0.isLetter || $0.isNumber }
        if let spelled = numeralEquivalents[alphanumeric] { return spelled }
        let folded: String
        if token.unicodeScalars.allSatisfy(\.isASCII) {
            folded = token.lowercased().filter(\.isLetter)
        } else {
            folded = token
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: foldingLocale)
                .filter(\.isLetter)
        }
        return spokenEquivalents[folded] ?? folded
    }

    static func tokensMatch(_ spoken: String, _ reference: String) -> Bool {
        guard spoken != reference else { return true }
        let tolerance: Int
        switch reference.count {
        case ..<4: return false
        case 4...6: tolerance = 1
        default: tolerance = 2
        }
        return levenshtein(spoken, reference, limit: tolerance) <= tolerance
    }

    private static func levenshtein(_ a: String, _ b: String, limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        let aChars = Array(a)
        let bChars = Array(b)
        var previous = Array(0...bChars.count)
        for (i, aChar) in aChars.enumerated() {
            var current = [i + 1]
            current.reserveCapacity(bChars.count + 1)
            for (j, bChar) in bChars.enumerated() {
                let substitution = previous[j] + (aChar == bChar ? 0 : 1)
                current.append(min(previous[j + 1] + 1, current[j] + 1, substitution))
            }
            if current.min()! > limit { return limit + 1 }
            previous = current
        }
        return previous[bChars.count]
    }
}
