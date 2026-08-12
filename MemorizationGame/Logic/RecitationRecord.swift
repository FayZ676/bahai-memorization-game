import Foundation

struct RecitationMiss: Codable, Hashable, Identifiable {
    var id = UUID()
    var wordIndex: Int
    var expected: String
    var heard: String
    var expectedKey: String
    var heardKeys: [String]

    enum CodingKeys: String, CodingKey {
        case id, wordIndex, expected, heard, expectedKey, heardKeys
    }

    init(
        id: UUID = UUID(),
        wordIndex: Int,
        expected: String,
        heard: String,
        expectedKey: String,
        heardKeys: [String]
    ) {
        self.id = id
        self.wordIndex = wordIndex
        self.expected = expected
        self.heard = heard
        self.expectedKey = expectedKey
        self.heardKeys = heardKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        wordIndex = try container.decode(Int.self, forKey: .wordIndex)
        expected = try container.decode(String.self, forKey: .expected)
        heard = try container.decode(String.self, forKey: .heard)
        expectedKey = try container.decodeIfPresent(String.self, forKey: .expectedKey) ?? ""
        heardKeys = try container.decodeIfPresent([String].self, forKey: .heardKeys) ?? []
    }

    var heardSomething: Bool { !heard.isEmpty }
}

struct RecitationAttempt: Codable, Hashable, Identifiable {
    var id = UUID()
    var chunkID: UUID
    var date: Date
    var passageTitle: String
    var excerpt: String
    var expectedCount: Int
    var matchedCount: Int
    var misses: [RecitationMiss]
    var transcript: String

    enum CodingKeys: String, CodingKey {
        case id, chunkID, date, passageTitle, excerpt, expectedCount, matchedCount, misses, transcript
    }

    init(
        id: UUID = UUID(),
        chunkID: UUID,
        date: Date = Date(),
        passageTitle: String,
        excerpt: String,
        expectedCount: Int,
        matchedCount: Int,
        misses: [RecitationMiss],
        transcript: String
    ) {
        self.id = id
        self.chunkID = chunkID
        self.date = date
        self.passageTitle = passageTitle
        self.excerpt = excerpt
        self.expectedCount = expectedCount
        self.matchedCount = matchedCount
        self.misses = misses
        self.transcript = transcript
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        chunkID = try container.decode(UUID.self, forKey: .chunkID)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        passageTitle = try container.decodeIfPresent(String.self, forKey: .passageTitle) ?? ""
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt) ?? ""
        expectedCount = try container.decodeIfPresent(Int.self, forKey: .expectedCount) ?? 0
        matchedCount = try container.decodeIfPresent(Int.self, forKey: .matchedCount) ?? 0
        misses = try container.decodeIfPresent([RecitationMiss].self, forKey: .misses) ?? []
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript) ?? ""
    }

    var summary: String {
        misses.isEmpty ? "no misses" : "\(misses.count) missed"
    }
}

struct RecitationDraft {
    var expectedCount: Int
    var matchedCount: Int
    var misses: [RecitationMiss]
    var transcript: String

    var isEmpty: Bool { misses.isEmpty && matchedCount == 0 }

    func attempt(chunkID: UUID, passageTitle: String, excerpt: String) -> RecitationAttempt {
        RecitationAttempt(
            chunkID: chunkID,
            passageTitle: passageTitle,
            excerpt: excerpt,
            expectedCount: expectedCount,
            matchedCount: matchedCount,
            misses: misses,
            transcript: transcript
        )
    }
}
