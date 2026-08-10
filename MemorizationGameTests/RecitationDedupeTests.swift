import Testing

@testable import MemorizationGame

private struct Harness {
    var matcher: RecitationMatcher
    var consumption = TranscriptConsumption()
    var matched: [Int] = []
    var missed: [(index: Int, movedOn: Bool)] = []

    init(words: [String], hidden: [Int]) {
        matcher = RecitationMatcher(words: words, hiddenIndices: hidden)
    }

    mutating func ingest(_ tokens: [TimedToken], isFinal: Bool) {
        let pending = consumption.pending(in: tokens)
        guard !pending.isEmpty else { return }
        matcher.resetSegmentCursor()
        let words = pending.map(\.text)
        let events = isFinal ? matcher.finalizeSegment(words) : matcher.updateVolatile(words)
        for event in events {
            switch event {
            case .matched(let index): matched.append(index)
            case .missed(let index, let movedOn): missed.append((index, movedOn))
            }
        }
        consumption.advance(over: pending, committed: matcher.segmentCursor)
    }
}

private func timed(_ pairs: [(String, Double)]) -> [TimedToken] {
    pairs.map { TimedToken(text: $0.0, end: $0.1) }
}

@Suite("Finalization re-feed, from the captured recitation")
struct RefeedTests {
    static let words = [
        "Thee.", "I", "testify,", "at", "this", "moment,", "to", "my", "powerlessness",
    ]

    @Test("A finalization burst over already-matched audio produces no events")
    func burstOverMatchedAudioIsInert() {
        var h = Harness(words: Self.words, hidden: Array(Self.words.indices))
        h.ingest(
            timed([
                ("I", 8.52), ("testify", 9.0), ("at", 9.48), ("this", 9.6),
                ("moment", 10.0), ("to", 10.08), ("my", 10.29),
            ]),
            isFinal: false
        )
        #expect(h.matched == [1, 2, 3, 4, 5, 6, 7])
        let missCountBefore = h.missed.count
        h.ingest(timed([("I", 8.52)]), isFinal: true)
        h.ingest(timed([("testify", 9.0), ("at", 9.48)]), isFinal: true)
        h.ingest(timed([("this", 9.6)]), isFinal: true)
        h.ingest(timed([("moment", 10.0), ("to", 10.08)]), isFinal: true)
        h.ingest(timed([("my", 10.29)]), isFinal: true)
        #expect(h.missed.count == missCountBefore)
        #expect(h.matched == [1, 2, 3, 4, 5, 6, 7])
        #expect(h.matcher.nextExpectedIndex == 8)
    }

    @Test("A fragment straddling the consumed boundary feeds only its unconsumed suffix")
    func straddlingFragmentFeedsSuffixOnly() {
        var h = Harness(words: Self.words, hidden: Array(Self.words.indices))
        h.ingest(timed([("Thee", 7.0), ("I", 8.52)]), isFinal: false)
        #expect(h.matched == [0, 1])
        h.ingest(timed([("Thee", 7.0), ("I", 8.52), ("testify", 9.0)]), isFinal: true)
        #expect(h.matched == [0, 1, 2])
        #expect(h.missed.isEmpty)
    }

    @Test("Unmatched audio is never dropped by the dedupe")
    func unmatchedAudioStaysPending() {
        var h = Harness(words: Self.words, hidden: Array(Self.words.indices))
        h.ingest(timed([("zzz", 1.0)]), isFinal: false)
        #expect(h.matched.isEmpty)
        h.ingest(timed([("zzz", 1.0), ("Thee", 2.0)]), isFinal: false)
        #expect(h.matched == [0])
    }
}

@Suite("Advance policy is unchanged from main")
struct PolicyPreservationTests {
    static let words = ["Praise", "be", "to", "Thee", "O", "God"]

    @Test("A volatile pass still commits a miss once two tokens have passed it")
    func volatileLeftBehindStillCommits() {
        var h = Harness(words: Self.words, hidden: [0])
        h.ingest(timed([("zzz", 1.0), ("yyy", 2.0), ("www", 3.0), ("qqq", 4.0)]), isFinal: false)
        #expect(h.missed.contains { $0.index == 0 })
    }

    @Test("Two failed attempts still move the pointer on")
    func twoStrikesStillMovesOn() {
        var h = Harness(words: Self.words, hidden: [0])
        h.ingest(timed([("zzz", 1.0)]), isFinal: true)
        #expect(h.missed.map(\.movedOn) == [false])
        h.ingest(timed([("yyy", 2.0)]), isFinal: true)
        #expect(h.missed.map(\.movedOn) == [false, true])
        #expect(h.matcher.isComplete)
    }

    @Test("A straight recitation matches every hidden word with no misses")
    func straightRecitationStillWorks() {
        var h = Harness(words: Self.words, hidden: [0, 3, 5])
        h.ingest(
            timed([
                ("Praise", 1.0), ("be", 1.5), ("to", 2.0),
                ("Thee", 2.5), ("O", 3.0), ("God", 3.5),
            ]),
            isFinal: true
        )
        #expect(h.matched == [0, 3, 5])
        #expect(h.missed.isEmpty)
        #expect(h.matcher.isComplete)
    }
}

@Suite("Transcript consumption")
struct TranscriptConsumptionTests {
    @Test("Only tokens after the consumed boundary are pending")
    func pendingRespectsBoundary() {
        var c = TranscriptConsumption()
        let tokens = timed([("a", 1.0), ("b", 2.0), ("c", 3.0)])
        #expect(c.pending(in: tokens) == tokens)
        c.advance(over: tokens, committed: 2)
        #expect(c.pending(in: tokens) == [TimedToken(text: "c", end: 3.0)])
    }

    @Test("Committing nothing leaves everything pending")
    func zeroCommitIsNoOp() {
        var c = TranscriptConsumption()
        let tokens = timed([("a", 1.0)])
        c.advance(over: tokens, committed: 0)
        #expect(c.pending(in: tokens) == tokens)
    }

    @Test("The boundary never moves backwards")
    func boundaryIsMonotonic() {
        var c = TranscriptConsumption()
        c.advance(over: timed([("a", 5.0)]), committed: 1)
        c.advance(over: timed([("b", 3.0)]), committed: 1)
        #expect(c.pending(in: timed([("c", 4.0)])).isEmpty)
    }
}
