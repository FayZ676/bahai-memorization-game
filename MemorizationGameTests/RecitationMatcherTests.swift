import Testing

@testable import MemorizationGame

private let verse = ["Praise", "be", "to", "Thee", "O", "All", "-Glorious", "Lord"]

private func matchedIndices(_ events: [RecitationMatcher.Event]) -> [Int] {
    events.compactMap { event in
        if case .matched(let index) = event { return index }
        return nil
    }
}

private func missedIndices(_ events: [RecitationMatcher.Event]) -> [Int] {
    events.compactMap { event in
        if case .missed(let index, _) = event { return index }
        return nil
    }
}

private func movedOnIndices(_ events: [RecitationMatcher.Event]) -> [Int] {
    events.compactMap { event in
        if case .missed(let index, let movedOn) = event, movedOn { return index }
        return nil
    }
}

@Suite("Hyphenated compounds")
struct CompoundMatchingTests {
    @Test("A compound spoken as one joined token matches every fragment")
    func joinedCompound() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [5, 6])
        let events = matcher.finalizeSegment(["All-Glorious"])
        #expect(matchedIndices(events) == [5, 6])
        #expect(matcher.isComplete)
    }

    @Test("A compound spoken as separate tokens still matches every fragment")
    func splitCompound() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [5, 6])
        let events = matcher.finalizeSegment(["all", "glorious"])
        #expect(matchedIndices(events) == [5, 6])
    }

    @Test("A joined token matches when only the trailing fragment is hidden")
    func trailingFragmentOnly() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [6])
        let events = matcher.finalizeSegment(["All-Glorious"])
        #expect(matchedIndices(events) == [6])
    }
}

@Suite("Volatile results")
struct VolatileResultTests {
    @Test("A volatile pass never commits a miss")
    func volatileCommitsNothing() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0])
        let events = matcher.updateVolatile(["zzz", "yyy", "www", "qqq"])
        #expect(events.isEmpty)
        #expect(matcher.nextExpectedIndex == 0)
    }

    @Test("A volatile pass still reports matches")
    func volatileStillMatches() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0])
        let events = matcher.updateVolatile(["Praise"])
        #expect(matchedIndices(events) == [0])
    }

    @Test("A final pass moves on only after three failed tokens")
    func finalMovesOnAfterThreeFailures() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0])
        #expect(movedOnIndices(matcher.finalizeSegment(["zzz"])).isEmpty)
        #expect(movedOnIndices(matcher.finalizeSegment(["yyy"])).isEmpty)
        #expect(movedOnIndices(matcher.finalizeSegment(["www"])) == [0])
    }
}

@Suite("Alternative transcriptions")
struct AlternativeTranscriptionTests {
    @Test("An alternative rescues a word the primary transcription got wrong")
    func alternativeRescuesMatch() {
        #expect(!RecitationMatcher.tokensMatch("prays", "praise"))
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0])
        let events = matcher.finalizeSegment(["prays"], alternatives: [["praise"]])
        #expect(matchedIndices(events) == [0])
    }

    @Test("Alternatives do not invent matches for genuinely wrong words")
    func alternativesDoNotFabricate() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0])
        let events = matcher.finalizeSegment(["zzz"], alternatives: [["qqq"]])
        #expect(matchedIndices(events).isEmpty)
    }
}

@Suite("Token normalization")
struct NormalizationTests {
    @Test("Numerals normalize to the words they are spoken as")
    func numerals() {
        #expect(RecitationMatcher.normalize("1") == "one")
        #expect(RecitationMatcher.normalize("100") == "hundred")
    }

    @Test("Diacritics and punctuation fold away")
    func folding() {
        #expect(RecitationMatcher.normalize("Bahá'u'lláh") == "bahaullah")
        #expect(RecitationMatcher.normalize("Thy,") == "thy")
    }

    @Test("Short reference words demand an exact match")
    func shortWordsAreStrict() {
        #expect(RecitationMatcher.tokensMatch("thy", "thy"))
        #expect(!RecitationMatcher.tokensMatch("thee", "thy"))
    }
}

@Suite("Sequential recitation")
struct SequentialRecitationTests {
    @Test("A full correct recitation matches every hidden word")
    func fullRecitation() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0, 3, 7])
        let events = matcher.finalizeSegment(
            ["Praise", "be", "to", "Thee", "O", "All-Glorious", "Lord"]
        )
        #expect(matchedIndices(events) == [0, 3, 7])
        #expect(matcher.isComplete)
    }

    @Test("A skipped hidden word is reported as missed")
    func skippedWordReported() {
        var matcher = RecitationMatcher(words: verse, hiddenIndices: [0, 3])
        let events = matcher.finalizeSegment(["Praise", "be", "to", "Lord"])
        #expect(matchedIndices(events).contains(0))
        #expect(missedIndices(events).contains(3))
    }
}
