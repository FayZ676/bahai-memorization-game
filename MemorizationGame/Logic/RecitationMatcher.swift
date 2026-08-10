import Foundation

struct RecitationMatcher {
    enum Event: Equatable {
        case matched(index: Int)
        case missed(index: Int, movedOn: Bool)
    }

    struct HeardToken {
        let text: String
        let key: String
        let confidence: Double

        init(text: some StringProtocol, confidence: Double) {
            self.text = String(text)
            self.key = PhoneticKey.encode(text)
            self.confidence = confidence
        }
    }

    private struct Progress {
        var cursor = 0
        var queuePosition = 0
        var attempts = 0
    }

    private static let lookahead = 12
    private static let attemptBudget = 3
    private static let confidenceFloor = 0.25

    private let words: [String]
    private var hiddenIndices: [Int]
    private var committed = Progress()
    private var live = Progress()
    private var announced: Set<Int> = []

    init(words: [String], hiddenIndices: [Int]) {
        self.words = words.map(PhoneticKey.encode)
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < words.count }.sorted()
    }

    var isComplete: Bool { committed.queuePosition >= hiddenIndices.count }
    var nextExpectedIndex: Int? { checkpoint(in: live) }

    var diagnostic: String {
        let expected = nextExpectedIndex.map { "\($0):\(words[$0])" } ?? "done"
        return "cursor=\(live.cursor) expect=\(expected) attempts=\(committed.attempts)"
    }

    mutating func replaceHidden(with indices: [Int]) {
        let frontier = checkpoint(in: committed) ?? words.count
        hiddenIndices = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        committed.queuePosition = hiddenIndices.firstIndex { $0 >= frontier } ?? hiddenIndices.count
        committed.attempts = 0
        live = committed
        announced.removeAll()
    }

    mutating func ingest(_ tokens: [HeardToken], isFinal: Bool) -> [Event] {
        var state = committed
        let events = scan(tokens, state: &state, commitMisses: isFinal)
        live = state

        var output: [Event] = []
        for event in events {
            guard case .matched(let index) = event else {
                output.append(event)
                continue
            }
            if announced.insert(index).inserted { output.append(event) }
        }

        if isFinal {
            committed = state
            announced.removeAll()
        }
        return output
    }

    private func checkpoint(in state: Progress) -> Int? {
        state.queuePosition < hiddenIndices.count ? hiddenIndices[state.queuePosition] : nil
    }

    private func scan(
        _ tokens: [HeardToken],
        state: inout Progress,
        commitMisses: Bool
    ) -> [Event] {
        let spoken = tokens.filter { !$0.key.isEmpty }
        let start = state.cursor
        let windowEnd = min(words.count, start + Self.lookahead)
        guard !spoken.isEmpty, windowEnd > start else { return [] }

        let alignment = Self.align(
            spoken: spoken.map(\.key),
            reference: Array(words[start..<windowEnd])
        )

        var events: [Event] = []
        let reached = start + alignment.referenceConsumed
        while let checkpoint = checkpoint(in: state), checkpoint < reached {
            if alignment.matchedOffsets.contains(checkpoint - start) {
                events.append(.matched(index: checkpoint))
            } else if commitMisses {
                events.append(.missed(index: checkpoint, movedOn: true))
            }
            state.queuePosition += 1
            state.attempts = 0
        }
        state.cursor = max(state.cursor, reached)

        guard commitMisses,
              alignment.matchedOffsets.isEmpty,
              let checkpoint = checkpoint(in: state),
              spoken.contains(where: { $0.confidence >= Self.confidenceFloor })
        else { return events }

        state.attempts += 1
        if state.attempts >= Self.attemptBudget {
            events.append(.missed(index: checkpoint, movedOn: true))
            state.queuePosition += 1
            state.attempts = 0
            state.cursor = max(state.cursor, checkpoint + 1)
        } else {
            events.append(.missed(index: checkpoint, movedOn: false))
        }
        return events
    }

    private struct Alignment {
        let referenceConsumed: Int
        let matchedOffsets: Set<Int>
    }

    private static func align(spoken: [String], reference: [String]) -> Alignment {
        let spokenCount = spoken.count
        let referenceCount = reference.count
        guard spokenCount > 0, referenceCount > 0 else {
            return Alignment(referenceConsumed: 0, matchedOffsets: [])
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
        var row = spokenCount
        var column = best
        while row > 0, column > 0 {
            let aligned = PhoneticKey.matches(spoken[row - 1], reference[column - 1])
            if cost[row][column] == cost[row - 1][column - 1] + (aligned ? 0 : 1) {
                if aligned { matched.insert(column - 1) }
                row -= 1
                column -= 1
            } else if cost[row][column] == cost[row - 1][column] + 1 {
                row -= 1
            } else {
                column -= 1
            }
        }

        return Alignment(referenceConsumed: best, matchedOffsets: matched)
    }
}
