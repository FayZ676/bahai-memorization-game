import Testing

@testable import MemorizationGame

@Suite("Transcript consumption")
struct TranscriptConsumptionTests {
    @Test("Every token is pending before anything is consumed")
    func allPendingInitially() {
        let consumption = TranscriptConsumption()
        let tokens = [
            TimedToken(text: "I", end: 1.0),
            TimedToken(text: "bear", end: 2.0),
        ]
        #expect(consumption.pending(in: tokens) == tokens)
    }

    @Test("Tokens already matched are not offered again")
    func consumedTokensDropOut() {
        var consumption = TranscriptConsumption()
        let first = [
            TimedToken(text: "I", end: 1.0),
            TimedToken(text: "bear", end: 2.0),
            TimedToken(text: "witness", end: 3.0),
        ]
        consumption.advance(over: first, committed: 3)
        let repeated = first + [TimedToken(text: "O", end: 4.0)]
        #expect(consumption.pending(in: repeated) == [TimedToken(text: "O", end: 4.0)])
    }

    @Test("A finalized fragment covering already-matched audio yields nothing")
    func staleFinalFragmentIsSkipped() {
        var consumption = TranscriptConsumption()
        let volatileTokens = [
            TimedToken(text: "I", end: 8.52),
            TimedToken(text: "testify", end: 9.0),
            TimedToken(text: "at", end: 9.48),
        ]
        consumption.advance(over: volatileTokens, committed: 3)
        let staleFragment = [TimedToken(text: "I", end: 8.52)]
        #expect(consumption.pending(in: staleFragment).isEmpty)
    }

    @Test("Unmatched trailing tokens stay available for a later result")
    func unmatchedTailRemainsPending() {
        var consumption = TranscriptConsumption()
        let tokens = [
            TimedToken(text: "poverty", end: 1.0),
            TimedToken(text: "into", end: 2.0),
            TimedToken(text: "thy", end: 3.0),
        ]
        consumption.advance(over: tokens, committed: 1)
        #expect(consumption.pending(in: tokens) == Array(tokens.dropFirst()))
    }

    @Test("Committing nothing leaves the whole result pending")
    func noCommitLeavesEverythingPending() {
        var consumption = TranscriptConsumption()
        let tokens = [TimedToken(text: "V", end: 1.0)]
        consumption.advance(over: tokens, committed: 0)
        #expect(consumption.pending(in: tokens) == tokens)
    }
}
