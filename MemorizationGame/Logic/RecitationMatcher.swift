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

    private static let attemptBudget = 3
    private static let confidenceFloor = 0.25
    private static let movedOnMargin = 2

    private let words: [String]
    private var hiddenIndices: [Int]
    private var settled: [HeardToken] = []
    private var pending: [HeardToken] = []
    private var matched: Set<Int> = []
    private var missed: Set<Int> = []
    private var frontier = -1
    private var attempts = 0

    init(words: [String], hiddenIndices: [Int]) {
        self.words = words.map(PhoneticKey.encode)
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < words.count }.sorted()
    }

    var isComplete: Bool {
        hiddenIndices.allSatisfy { matched.contains($0) || missed.contains($0) }
    }

    var nextExpectedIndex: Int? {
        hiddenIndices.first { !matched.contains($0) && !missed.contains($0) }
    }

    var diagnostic: String {
        let expected = nextExpectedIndex.map { "\($0):\(words[$0])" } ?? "done"
        return "expect=\(expected) frontier=\(frontier) attempts=\(attempts) settled=\(settled.count)"
    }

    mutating func replaceHidden(with indices: [Int]) {
        hiddenIndices = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        attempts = 0
    }

    mutating func ingest(_ tokens: [HeardToken], isFinal: Bool) -> [Event] {
        let usable = tokens.filter { !$0.key.isEmpty }
        if isFinal {
            settled.append(contentsOf: usable)
            pending = []
        } else {
            pending = usable
        }

        let spoken = settled + pending
        guard !spoken.isEmpty else { return [] }
        let alignment = Self.align(spoken: spoken.map(\.key), reference: words)
        let reached = alignment.reference

        var events: [Event] = []
        for index in hiddenIndices where reached.contains(index) {
            guard !matched.contains(index), !missed.contains(index) else { continue }
            matched.insert(index)
            events.append(.matched(index: index))
        }

        let advanced = reached.max() ?? -1
        let progressed = advanced > frontier
        if progressed {
            frontier = advanced
            attempts = 0
        }

        if isFinal {
            for index in hiddenIndices where index + Self.movedOnMargin < frontier {
                guard !matched.contains(index), !missed.contains(index) else { continue }
                missed.insert(index)
                events.append(.missed(index: index, movedOn: true))
            }
        }

        let arrived = (spoken.count - usable.count)..<spoken.count
        let unexplained = arrived.contains {
            spoken[$0].confidence >= Self.confidenceFloor && !alignment.spoken.contains($0)
        }

        guard isFinal, !progressed, unexplained, let expected = nextExpectedIndex
        else { return events }

        attempts += 1
        if attempts >= Self.attemptBudget {
            missed.insert(expected)
            attempts = 0
            events.append(.missed(index: expected, movedOn: true))
        } else {
            events.append(.missed(index: expected, movedOn: false))
        }
        return events
    }

    private struct Alignment {
        let reference: Set<Int>
        let spoken: Set<Int>
    }

    private static func align(spoken: [String], reference: [String]) -> Alignment {
        let spokenCount = spoken.count
        let referenceCount = reference.count
        guard spokenCount > 0, referenceCount > 0 else { return Alignment(reference: [], spoken: []) }

        var lookup: [String: Set<String>] = [:]
        let aligned = spoken.map { spokenKey in
            reference.map { referenceKey in
                if let known = lookup[referenceKey] { return known.contains(spokenKey) }
                var equivalents: Set<String> = []
                for candidate in Set(spoken) where PhoneticKey.matches(candidate, referenceKey) {
                    equivalents.insert(candidate)
                }
                lookup[referenceKey] = equivalents
                return equivalents.contains(spokenKey)
            }
        }
        func aligns(_ row: Int, _ column: Int) -> Bool { aligned[row][column] }

        var cost = Array(
            repeating: Array(repeating: 0, count: referenceCount + 1),
            count: spokenCount + 1
        )
        for row in 0...spokenCount { cost[row][0] = row }
        for row in 1...spokenCount {
            for column in 1...referenceCount {
                cost[row][column] = min(
                    cost[row - 1][column - 1] + (aligns(row - 1, column - 1) ? 0 : 1),
                    cost[row - 1][column] + 1,
                    cost[row][column - 1] + 1
                )
            }
        }

        var best = 0
        for column in 0...referenceCount where cost[spokenCount][column] < cost[spokenCount][best] {
            best = column
        }

        var hitReference: Set<Int> = []
        var hitSpoken: Set<Int> = []
        var row = spokenCount
        var column = best
        while row > 0, column > 0 {
            if cost[row][column] == cost[row - 1][column - 1] + (aligns(row - 1, column - 1) ? 0 : 1) {
                if aligns(row - 1, column - 1) {
                    hitReference.insert(column - 1)
                    hitSpoken.insert(row - 1)
                }
                row -= 1
                column -= 1
            } else if cost[row][column] == cost[row - 1][column] + 1 {
                row -= 1
            } else {
                column -= 1
            }
        }
        return Alignment(reference: hitReference, spoken: hitSpoken)
    }
}
