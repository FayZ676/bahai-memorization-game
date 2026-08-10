import Foundation

struct RecitationMatcher {
    enum Event: Equatable {
        case matched(index: Int)
        case missed(index: Int, movedOn: Bool)
    }

    struct HeardToken {
        let key: String
        let confidence: Double
        let start: Double
        let end: Double

        init(text: some StringProtocol, confidence: Double, start: Double, end: Double) {
            self.key = PhoneticKey.encode(text)
            self.confidence = confidence
            self.start = start
            self.end = end
        }
    }

    private static let lookahead = 12
    private static let utteranceGap = 0.6
    private static let attemptBudget = 3
    private static let confidenceFloor = 0.25

    private let words: [String]
    private var hiddenIndices: [Int]
    private var cursor = 0
    private var queuePosition = 0
    private var attempts = 0
    private var consumedUpTo = 0.0

    init(words: [String], hiddenIndices: [Int]) {
        self.words = words.map(PhoneticKey.encode)
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < words.count }.sorted()
    }

    var isComplete: Bool { queuePosition >= hiddenIndices.count }
    var nextExpectedIndex: Int? { isComplete ? nil : hiddenIndices[queuePosition] }

    mutating func replaceHidden(with indices: [Int]) {
        let frontier = nextExpectedIndex ?? words.count
        hiddenIndices = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        queuePosition = hiddenIndices.firstIndex { $0 >= frontier } ?? hiddenIndices.count
        attempts = 0
    }

    mutating func ingest(_ tokens: [HeardToken], finalizedThrough: Double) -> [Event] {
        let pending = tokens.filter { !$0.key.isEmpty && $0.end > consumedUpTo }
        guard !pending.isEmpty else { return [] }
        var events: [Event] = []
        for utterance in Self.utterances(in: pending) {
            guard !isComplete else { break }
            events += absorb(utterance, settled: utterance.allSatisfy { $0.end <= finalizedThrough })
        }
        return events
    }

    private mutating func absorb(_ utterance: [HeardToken], settled: Bool) -> [Event] {
        let start = cursor
        let windowEnd = min(words.count, start + Self.lookahead)
        guard windowEnd > start else { return [] }
        let alignment = Self.align(
            spoken: utterance.map(\.key),
            reference: Array(words[start..<windowEnd])
        )

        var events: [Event] = []
        let reached = start + alignment.referenceConsumed
        while let checkpoint = nextExpectedIndex, checkpoint < reached {
            let matched = alignment.matchedOffsets.contains(checkpoint - start)
            events.append(
                matched
                    ? .matched(index: checkpoint)
                    : .missed(index: checkpoint, movedOn: true)
            )
            queuePosition += 1
            attempts = 0
        }
        cursor = max(cursor, reached)

        if let index = alignment.lastMatchedTokenIndex {
            consumedUpTo = utterance[index].end
        }
        guard settled, let last = utterance.last else { return events }
        consumedUpTo = max(consumedUpTo, last.end)

        guard alignment.matchedOffsets.isEmpty,
              let checkpoint = nextExpectedIndex,
              utterance.contains(where: { $0.confidence >= Self.confidenceFloor })
        else { return events }

        attempts += 1
        if attempts >= Self.attemptBudget {
            events.append(.missed(index: checkpoint, movedOn: true))
            queuePosition += 1
            attempts = 0
            cursor = max(cursor, checkpoint + 1)
        } else {
            events.append(.missed(index: checkpoint, movedOn: false))
        }
        return events
    }

    private static func utterances(in tokens: [HeardToken]) -> [[HeardToken]] {
        var result: [[HeardToken]] = []
        var current: [HeardToken] = []
        for token in tokens {
            if let last = current.last, token.start - last.end > utteranceGap {
                result.append(current)
                current = []
            }
            current.append(token)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private struct Alignment {
        let referenceConsumed: Int
        let matchedOffsets: Set<Int>
        let lastMatchedTokenIndex: Int?
    }

    private static func align(spoken: [String], reference: [String]) -> Alignment {
        let spokenCount = spoken.count
        let referenceCount = reference.count
        guard spokenCount > 0, referenceCount > 0 else {
            return Alignment(referenceConsumed: 0, matchedOffsets: [], lastMatchedTokenIndex: nil)
        }

        var cost = Array(
            repeating: Array(repeating: 0, count: referenceCount + 1),
            count: spokenCount + 1
        )
        for column in 0...referenceCount { cost[0][column] = column }
        for row in 0...spokenCount { cost[row][0] = row }
        for row in 1...spokenCount {
            for column in 1...referenceCount {
                let aligned = PhoneticKey.matches(spoken[row - 1], reference[column - 1])
                cost[row][column] = min(
                    cost[row - 1][column - 1] + (aligned ? 0 : 1),
                    cost[row - 1][column] + 1,
                    cost[row][column - 1] + 1
                )
            }
        }

        var best = 0
        for column in 0...referenceCount where cost[spokenCount][column] < cost[spokenCount][best] {
            best = column
        }

        var matched: Set<Int> = []
        var lastToken: Int?
        var row = spokenCount
        var column = best
        while row > 0, column > 0 {
            let aligned = PhoneticKey.matches(spoken[row - 1], reference[column - 1])
            if cost[row][column] == cost[row - 1][column - 1] + (aligned ? 0 : 1) {
                if aligned {
                    matched.insert(column - 1)
                    if lastToken == nil { lastToken = row - 1 }
                }
                row -= 1
                column -= 1
            } else if cost[row][column] == cost[row - 1][column] + 1 {
                row -= 1
            } else {
                column -= 1
            }
        }

        return Alignment(
            referenceConsumed: best,
            matchedOffsets: matched,
            lastMatchedTokenIndex: lastToken
        )
    }
}
