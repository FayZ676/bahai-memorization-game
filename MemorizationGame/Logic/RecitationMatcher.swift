import Foundation

struct RecitationMatcher {
    enum Event: Equatable {
        case matched(indices: [Int])
        case missed
        case idle
    }

    private let reference: [String]
    private(set) var cursor = 0
    private var consumedTokenCount = 0

    init(reference: [String]) {
        self.reference = reference.map(Self.normalize)
    }

    var isComplete: Bool { cursor >= reference.count }
    var nextExpectedIndex: Int? { isComplete ? nil : cursor }

    mutating func beginNewUtteranceStream() {
        consumedTokenCount = 0
    }

    mutating func consume(partialTranscript: [String], isFinal: Bool) -> Event {
        let tokens = partialTranscript.map(Self.normalize).filter { !$0.isEmpty }
        if tokens.count < consumedTokenCount {
            consumedTokenCount = tokens.count
        }
        var matchedIndices: [Int] = []
        var committedMiss = false
        var index = consumedTokenCount
        while index < tokens.count, !isComplete {
            let tokenIsStable = index < tokens.count - 1 || isFinal
            if Self.tokensMatch(tokens[index], reference[cursor]) {
                matchedIndices.append(cursor)
                cursor += 1
            } else if tokenIsStable {
                committedMiss = true
            } else {
                break
            }
            consumedTokenCount = index + 1
            index += 1
        }
        if !matchedIndices.isEmpty { return .matched(indices: matchedIndices) }
        if committedMiss { return .missed }
        return .idle
    }

    static func normalize(_ token: some StringProtocol) -> String {
        token
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .filter(\.isLetter)
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
