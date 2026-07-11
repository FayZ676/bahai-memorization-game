import Testing
@testable import MemorizationGame

struct RecitationAlignerTests {
    let reference = "O Son of Spirit! My first counsel is this: Possess a pure, kindly and radiant heart,".split(separator: " ").map(String.init)

    @Test func exactRecitationReachesLastWord() {
        let transcript = reference.map { $0.lowercased() }
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == reference.count - 1)
    }

    @Test func partialRecitationStopsAtFrontier() {
        let transcript = ["o", "son", "of", "spirit"]
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == 3)
    }

    @Test func properNounSurvivesTransliteration() {
        let reference = ["the", "Day-Star", "of", "Bahá'u'lláh,"]
        let transcript = ["the", "daystar", "of", "bahaullah"]
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == 3)
    }

    @Test func substitutionMidStreamStillAdvances() {
        let transcript = ["o", "son", "of", "spirit", "my", "second", "counsel", "is", "this"]
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == 8)
    }

    @Test func insertionNoiseIsSkipped() {
        let transcript = ["o", "son", "um", "of", "spirit", "uh", "my", "first"]
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == 5)
    }

    @Test func emptyTranscriptGivesNoFrontier() {
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: []) == nil)
        #expect(RecitationAligner.matchedFrontier(reference: [], transcript: ["word"]) == nil)
    }

    @Test func unrelatedSpeechGivesNoFrontier() {
        let transcript = ["hello", "world", "testing"]
        #expect(RecitationAligner.matchedFrontier(reference: reference, transcript: transcript) == nil)
    }

    @Test func shortWordsRequireExactMatch() {
        #expect(!RecitationAligner.tokensMatch("the", "thy"))
        #expect(RecitationAligner.tokensMatch("thee", "the") == false)
        #expect(RecitationAligner.tokensMatch("kindley", "kindly"))
        #expect(RecitationAligner.tokensMatch("radient", "radiant"))
    }

    @Test func normalizeDropsPunctuationDiacriticsAndApostrophes() {
        #expect(RecitationAligner.normalize("Bahá'u'lláh,") == "bahaullah")
        #expect(RecitationAligner.normalize("heart,") == "heart")
        #expect(RecitationAligner.normalize("“Spirit!”") == "spirit")
    }
}
