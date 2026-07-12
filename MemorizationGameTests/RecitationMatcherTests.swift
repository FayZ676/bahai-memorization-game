import Testing
@testable import MemorizationGame

struct RecitationMatcherTests {
    let reference = "O Son of Spirit! My first counsel is this: Possess a pure, kindly and radiant heart,".split(separator: " ").map(String.init)

    @Test func incrementalPartialsMatchOneWordPerStep() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["o"], isFinal: false) == .matched(indices: [0]))
        #expect(matcher.consume(partialTranscript: ["o", "son"], isFinal: false) == .matched(indices: [1]))
        #expect(matcher.consume(partialTranscript: ["o", "son", "of"], isFinal: false) == .matched(indices: [2]))
        #expect(matcher.nextExpectedIndex == 3)
    }

    @Test func onePartialWithSeveralNewTokensMatchesSeveralWords() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["o", "son", "of", "spirit"], isFinal: false) == .matched(indices: [0, 1, 2, 3]))
    }

    @Test func trailingWrongTokenStaysIdleUntilStable() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["hello"], isFinal: false) == .idle)
        #expect(matcher.consume(partialTranscript: ["hello", "world"], isFinal: false) == .missed)
        #expect(matcher.consume(partialTranscript: ["hello", "world", "o"], isFinal: false) == .matched(indices: [0]))
    }

    @Test func finalResultCommitsTrailingMissImmediately() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["hello"], isFinal: true) == .missed)
        #expect(matcher.nextExpectedIndex == 0)
    }

    @Test func halfRecognizedWordRevisionNeverMisses() {
        var matcher = RecitationMatcher(reference: ["radiant", "heart"])
        #expect(matcher.consume(partialTranscript: ["radi"], isFinal: false) == .idle)
        #expect(matcher.consume(partialTranscript: ["radiant"], isFinal: false) == .matched(indices: [0]))
    }

    @Test func matchedWordsNeverUnmatchOnRevision() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["o", "son"], isFinal: false) == .matched(indices: [0, 1]))
        #expect(matcher.consume(partialTranscript: ["oh"], isFinal: false) == .idle)
        #expect(matcher.nextExpectedIndex == 2)
    }

    @Test func earlierSpeechCannotPrefillLaterWords() {
        var matcher = RecitationMatcher(reference: ["one", "two", "three"])
        #expect(matcher.consume(partialTranscript: ["two", "three"], isFinal: false) == .missed)
        #expect(matcher.nextExpectedIndex == 0)
        #expect(matcher.consume(partialTranscript: ["two", "three", "one", "two", "three"], isFinal: false) == .matched(indices: [0, 1, 2]))
    }

    @Test func matchesWinOverCooccurringMiss() {
        var matcher = RecitationMatcher(reference: reference)
        #expect(matcher.consume(partialTranscript: ["um", "o"], isFinal: false) == .matched(indices: [0]))
    }

    @Test func newUtteranceStreamKeepsCursor() {
        var matcher = RecitationMatcher(reference: reference)
        _ = matcher.consume(partialTranscript: ["o", "son"], isFinal: true)
        matcher.beginNewUtteranceStream()
        #expect(matcher.consume(partialTranscript: ["of"], isFinal: false) == .matched(indices: [2]))
    }

    @Test func completionStopsMatching() {
        var matcher = RecitationMatcher(reference: ["one", "two"])
        #expect(matcher.consume(partialTranscript: ["one", "two"], isFinal: false) == .matched(indices: [0, 1]))
        #expect(matcher.isComplete)
        #expect(matcher.nextExpectedIndex == nil)
        #expect(matcher.consume(partialTranscript: ["one", "two", "extra"], isFinal: true) == .idle)
    }

    @Test func properNounSurvivesTransliteration() {
        var matcher = RecitationMatcher(reference: ["the", "Day-Star", "of", "Bahá'u'lláh,"])
        #expect(matcher.consume(partialTranscript: ["the", "daystar", "of", "bahaullah"], isFinal: false) == .matched(indices: [0, 1, 2, 3]))
    }

    @Test func shortWordsRequireExactMatch() {
        #expect(!RecitationMatcher.tokensMatch("the", "thy"))
        #expect(RecitationMatcher.tokensMatch("thee", "the") == false)
        #expect(RecitationMatcher.tokensMatch("kindley", "kindly"))
        #expect(RecitationMatcher.tokensMatch("radient", "radiant"))
    }

    @Test func normalizeDropsPunctuationDiacriticsAndApostrophes() {
        #expect(RecitationMatcher.normalize("Bahá'u'lláh,") == "bahaullah")
        #expect(RecitationMatcher.normalize("heart,") == "heart")
        #expect(RecitationMatcher.normalize("“Spirit!”") == "spirit")
    }
}
