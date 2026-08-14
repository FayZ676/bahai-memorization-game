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
        let span: ClosedRange<TimeInterval>?

        init(
            text: some StringProtocol,
            confidence: Double,
            span: ClosedRange<TimeInterval>? = nil
        ) {
            self.text = String(text)
            self.key = PhoneticKey.encode(text)
            self.confidence = confidence
            self.span = span
        }
    }

    private static let attemptBudget = 3
    private static let confidenceFloor = 0.25
    private static let movedOnMargin = 2
    private static let unsettledMovedOnMargin = 6
    private static let unheardAllowance: TimeInterval = 0.25
    private static let movedOnCorroboration = 2

    private static func seconds(_ interval: TimeInterval?) -> String {
        interval.map { String(format: "%.2fs", $0) } ?? "-"
    }
    private static let lookahead = 12
    private static let heardWindow = 6

    private static let tryBudget = 60

    private let words: [String]
    private let spelling: [String]
    private var hiddenIndices: [Int]
    private(set) var misses: [RecitationMiss] = []
    private(set) var tries: [RecitationTry] = []
    private var triedThrough = 0
    private var settled: [HeardToken] = []
    private var pending: [HeardToken] = []
    private var matched: Set<Int> = []
    private var missed: Set<Int> = []
    private var frontier = -1
    private var attempts = 0
    private var judged = 0
    private var unexplainedSinceProgress = false

    init(words: [String], hiddenIndices: [Int]) {
        self.words = words.map(PhoneticKey.encode)
        self.spelling = words
        self.hiddenIndices = hiddenIndices.filter { $0 >= 0 && $0 < words.count }.sorted()
    }

    var transcript: String {
        (settled + pending).map(\.text).joined(separator: " ")
    }

    var matchedCount: Int { matched.count }

    var expectedCount: Int { max(hiddenIndices.count, matched.count + misses.count) }

    var isComplete: Bool {
        hiddenIndices.allSatisfy { matched.contains($0) || missed.contains($0) }
    }

    var nextExpectedIndex: Int? {
        hiddenIndices.first { !matched.contains($0) && !missed.contains($0) }
    }

    var cursorIndex: Int? {
        hiddenIndices.first { $0 >= frontier && !matched.contains($0) && !missed.contains($0) }
            ?? nextExpectedIndex
    }

    mutating func replaceHidden(with indices: [Int]) {
        let replacement = indices.filter { $0 >= 0 && $0 < words.count }.sorted()
        let dropped = hiddenIndices.filter {
            !replacement.contains($0) && !matched.contains($0) && !missed.contains($0)
        }
        for index in dropped {
            missed.insert(index)
            record(index, outcome: .revealed)
        }
        hiddenIndices = replacement
        attempts = 0
    }

    mutating func finish() {
        guard let owed = nextExpectedIndex, tries.contains(where: { $0.wordIndex == owed }) else {
            return
        }
        missed.insert(owed)
        record(owed, outcome: .abandoned)
    }

    mutating func ingest(_ tokens: [HeardToken], isFinal: Bool) -> [Event] {
        let owedBefore = nextExpectedIndex
        let usable = tokens.filter { !$0.key.isEmpty }
        if isFinal {
            settled.append(contentsOf: usable)
            pending = []
        } else {
            pending = usable
        }

        let spoken = settled + pending
        guard !spoken.isEmpty else { return [] }
        let alignStarted = Date()
        let budget = spoken.count + Self.lookahead
        let horizon = hiddenIndices.count > budget ? hiddenIndices[budget] + 1 : words.count
        let alignment = Self.align(
            spoken: spoken.map(\.key),
            reference: Array(words[0..<horizon]),
            required: Set(hiddenIndices)
        )
        let reached = alignment.reference
        RecitationTrace.emit(
            "align",
            """
            \(isFinal ? "FINAL " : "volatile") settled=\(settled.count) pending=\(pending.count) \
            spokenKeys=[\(spoken.map(\.key).joined(separator: " "))] \
            reached=\(reached.sorted()) unalignedSpoken=\(Array(0..<spoken.count).filter { !alignment.spoken.contains($0) }) \
            frontier=\(frontier) attempts=\(attempts) next=\(nextExpectedIndex.map(String.init) ?? "-") \
            horizon=\(horizon) in \(RecitationTrace.ms(since: alignStarted))
            """
        )

        var events: [Event] = []
        for index in hiddenIndices where reached.contains(index) {
            guard !matched.contains(index), !missed.contains(index) else { continue }
            matched.insert(index)
            events.append(.matched(index: index))
        }

        let advanced = reached.max() ?? -1
        let progressed = advanced > frontier
        let judgeable = isFinal ? spoken.count : spoken.count - 1
        if progressed {
            frontier = advanced
            attempts = 0
            unexplainedSinceProgress = false
        } else if judged < judgeable {
            unexplainedSinceProgress = unexplainedSinceProgress || (judged..<judgeable).contains {
                spoken[$0].confidence >= Self.confidenceFloor && !alignment.spoken.contains($0)
            }
        }
        judged = max(judged, judgeable)

        let margin = isFinal ? Self.movedOnMargin : Self.unsettledMovedOnMargin
        for index in hiddenIndices where index + margin < frontier {
            guard !matched.contains(index), !missed.contains(index) else { continue }
            let displaced = Self.tokens(displacing: index, spoken: spoken, alignment: alignment)
            let unheard = Self.unheardSpan(around: index, spoken: spoken, alignment: alignment)
            guard displaced.isEmpty,
                  (unheard ?? 0) < Self.unheardAllowance,
                  Self.movedOn(past: index, alignment: alignment)
            else {
                if isFinal {
                    RecitationTrace.emit(
                        "withhold",
                        "\(index) \"\(spelling[index])\" displaced by \(displaced.map(\.text)) "
                            + "unheard=\(Self.seconds(unheard))"
                    )
                }
                continue
            }
            RecitationTrace.emit(
                "skipped",
                "\(index) \"\(spelling[index])\" unheard=\(Self.seconds(unheard))"
            )
            missed.insert(index)
            record(index, spoken: spoken, alignment: alignment, outcome: .skipped)
            events.append(.missed(index: index, movedOn: true))
        }

        if isFinal {
            let fresh = Array(settled[min(triedThrough, settled.count)...])
            triedThrough = settled.count
            if let owedBefore {
                recordTry(owed: owedBefore, spoken: fresh, accepted: matched.contains(owedBefore))
            }
        }

        RecitationTrace.emit(
            "verdict",
            """
            progressed=\(progressed) unexplained=\(unexplainedSinceProgress) judged=\(judged) \
            hidden=\(hiddenIndices) matched=\(matched.sorted()) missed=\(missed.sorted()) events=\(events)
            """
        )

        guard isFinal, !progressed, unexplainedSinceProgress, let expected = nextExpectedIndex
        else { return events }

        unexplainedSinceProgress = false
        attempts += 1
        if attempts >= Self.attemptBudget {
            missed.insert(expected)
            attempts = 0
            record(expected, spoken: spoken, alignment: alignment, outcome: .exhausted)
            events.append(.missed(index: expected, movedOn: true))
        } else {
            events.append(.missed(index: expected, movedOn: false))
        }
        return events
    }

    private mutating func record(
        _ index: Int,
        spoken: [HeardToken],
        alignment: Alignment,
        outcome: RecitationOutcome
    ) {
        guard spelling.indices.contains(index) else { return }
        let instead = Self.tokens(displacing: index, spoken: spoken, alignment: alignment)
        misses.append(
            RecitationMiss(
                wordIndex: index,
                expected: spelling[index],
                heard: instead.map(\.text).joined(separator: " "),
                expectedKey: words[index],
                heardKeys: instead.map(\.key),
                outcome: outcome
            )
        )
    }

    private mutating func record(_ index: Int, outcome: RecitationOutcome) {
        guard spelling.indices.contains(index) else { return }
        let attempted = tries.filter { $0.wordIndex == index }
        RecitationTrace.emit(
            "\(outcome.rawValue)",
            "\(index) \"\(spelling[index])\" after \(attempted.count) tr\(attempted.count == 1 ? "y" : "ies")"
        )
        misses.append(
            RecitationMiss(
                wordIndex: index,
                expected: spelling[index],
                heard: attempted.map(\.heard).filter { !$0.isEmpty }.joined(separator: " / "),
                expectedKey: words[index],
                heardKeys: attempted.flatMap(\.heardKeys),
                outcome: outcome
            )
        )
    }

    private mutating func recordTry(owed: Int, spoken: [HeardToken], accepted: Bool) {
        let fresh = spoken.filter { $0.confidence >= Self.confidenceFloor }
        guard spelling.indices.contains(owed), tries.count < Self.tryBudget, !fresh.isEmpty else {
            return
        }
        RecitationTrace.emit(
            "try",
            "\(owed) \"\(spelling[owed])\" heard [\(fresh.map(\.text).joined(separator: " "))] "
                + "accepted=\(accepted)"
        )
        tries.append(
            RecitationTry(
                wordIndex: owed,
                expected: spelling[owed],
                heard: fresh.map(\.text).joined(separator: " "),
                expectedKey: words[owed],
                heardKeys: fresh.map(\.key),
                accepted: accepted
            )
        )
    }

    private static func movedOn(past index: Int, alignment: Alignment) -> Bool {
        var corroborating = 0
        for reference in alignment.pairs.keys where reference > index {
            corroborating += 1
            if corroborating >= movedOnCorroboration { return true }
        }
        return false
    }

    private static func anchors(
        around index: Int,
        alignment: Alignment
    ) -> (before: Int?, after: Int?) {
        (
            alignment.pairs.filter { $0.key < index }.map(\.value).max(),
            alignment.pairs.filter { $0.key > index }.map(\.value).min()
        )
    }

    private static func unheardSpan(
        around index: Int,
        spoken: [HeardToken],
        alignment: Alignment
    ) -> TimeInterval? {
        let (before, after) = anchors(around: index, alignment: alignment)
        guard let before, let after,
              spoken.indices.contains(before), spoken.indices.contains(after),
              let ended = spoken[before].span?.upperBound,
              let began = spoken[after].span?.lowerBound
        else { return nil }
        return began - ended
    }

    private static func tokens(
        displacing index: Int,
        spoken: [HeardToken],
        alignment: Alignment
    ) -> [HeardToken] {
        let (before, after) = anchors(around: index, alignment: alignment)
        let lower = (before ?? -1) + 1
        let upper = min(after ?? spoken.count, spoken.count)
        guard lower < upper else { return [] }
        return Array(spoken[lower..<min(upper, lower + Self.heardWindow)])
    }

    private struct Alignment {
        let pairs: [Int: Int]
        let spoken: Set<Int>

        var reference: Set<Int> { Set(pairs.keys) }
    }

    private static func align(
        spoken: [String],
        reference: [String],
        required: Set<Int>
    ) -> Alignment {
        let spokenCount = spoken.count
        let referenceCount = reference.count
        guard spokenCount > 0, referenceCount > 0 else { return Alignment(pairs: [:], spoken: []) }

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
                    cost[row][column - 1] + (required.contains(column - 1) ? 1 : 0)
                )
            }
        }

        var best = 0
        for column in 0...referenceCount where cost[spokenCount][column] < cost[spokenCount][best] {
            best = column
        }

        var pairs: [Int: Int] = [:]
        var hitSpoken: Set<Int> = []
        var row = spokenCount
        var column = best
        while row > 0, column > 0 {
            if cost[row][column] == cost[row - 1][column - 1] + (aligns(row - 1, column - 1) ? 0 : 1) {
                if aligns(row - 1, column - 1) {
                    pairs[column - 1] = row - 1
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
        return Alignment(pairs: pairs, spoken: hitSpoken)
    }
}
