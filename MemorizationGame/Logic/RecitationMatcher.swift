import Foundation

struct RecitationMatcher {
    enum Event: Equatable {
        case matched(index: Int)
        case missed(index: Int, movedOn: Bool)
    }

    private let words: [String]
    private var hiddenIndices: [Int]
    private var queuePosition = 0
    private var failedAttempts = 0
    private var segmentMatchConsumed = 0
    private var normalizedCache: [String: String] = [:]

    init(words: [String], hiddenIndices: [Int]) {
        self.words = words.map(Self.normalize)
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < words.count }.sorted()
    }

    var isComplete: Bool { queuePosition >= hiddenIndices.count }
    var nextExpectedIndex: Int? { isComplete ? nil : hiddenIndices[queuePosition] }

    mutating func replaceHidden(with indices: [Int]) {
        let frontier = nextExpectedIndex ?? words.count
        hiddenIndices = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        queuePosition = hiddenIndices.firstIndex { $0 >= frontier } ?? hiddenIndices.count
        failedAttempts = 0
    }

    var segmentCursor: Int { segmentMatchConsumed }

    mutating func resetSegmentCursor() {
        segmentMatchConsumed = 0
    }

    mutating func updateVolatile(_ segmentTokens: [String]) -> [Event] {
        scan(segmentTokens, commitMisses: false)
    }

    mutating func finalizeSegment(_ segmentTokens: [String]) -> [Event] {
        scan(segmentTokens, commitMisses: true)
    }

    private mutating func normalized(_ token: String) -> String {
        if let cached = normalizedCache[token] { return cached }
        let value = Self.normalize(token)
        normalizedCache[token] = value
        return value
    }

    private mutating func scan(_ segmentTokens: [String], commitMisses: Bool) -> [Event] {
        var tokens: [String] = []
        tokens.reserveCapacity(segmentTokens.count)
        for raw in segmentTokens {
            let token = normalized(raw)
            if !token.isEmpty { tokens.append(token) }
        }
        var events: [Event] = []
        var position = min(segmentMatchConsumed, tokens.count)
        while position < tokens.count, let expected = nextExpectedIndex {
            let token = tokens[position]
            let leftBehind = tokens.count - 1 - position >= 2
            defer { position += 1 }
            if Self.tokensMatch(token, words[expected]) {
                events.append(.matched(index: expected))
                advance()
                segmentMatchConsumed = position + 1
            } else if isIgnorableContext(token, before: expected) || !(commitMisses || leftBehind) {
            } else if let nextHidden = upcomingHiddenIndex, Self.tokensMatch(token, words[nextHidden]) {
                events.append(.missed(index: expected, movedOn: true))
                advance()
                events.append(.matched(index: nextHidden))
                advance()
                segmentMatchConsumed = position + 1
            } else if matchesSkipWindow(token, after: expected) {
                events.append(.missed(index: expected, movedOn: true))
                advance()
                segmentMatchConsumed = position + 1
            } else {
                failedAttempts += 1
                if failedAttempts >= 2 {
                    events.append(.missed(index: expected, movedOn: true))
                    advance()
                } else {
                    events.append(.missed(index: expected, movedOn: false))
                }
                segmentMatchConsumed = position + 1
            }
        }
        return events
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
        let window = words.indices.filter { $0 > expected && $0 <= expected + 2 }
        return window.contains { Self.tokensMatch(token, words[$0]) }
    }

    static let spokenEquivalents: [String: String] = [
        "oh": "o",
    ]

    private static let foldingLocale = Locale(identifier: "en_US")

    static func normalize(_ token: some StringProtocol) -> String {
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
