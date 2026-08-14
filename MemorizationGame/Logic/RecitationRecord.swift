import Foundation

enum RecitationOutcome: String, Codable, Hashable {
    case skipped
    case exhausted
    case revealed
    case abandoned

    var label: String {
        switch self {
        case .skipped: "skipped"
        case .exhausted: "gave up on it"
        case .revealed: "revealed"
        case .abandoned: "still owed at the end"
        }
    }
}

struct RecitationMiss: Codable, Hashable, Identifiable {
    var id = UUID()
    var wordIndex: Int
    var expected: String
    var heard: String
    var expectedKey: String
    var heardKeys: [String]
    var outcome: RecitationOutcome

    enum CodingKeys: String, CodingKey {
        case id, wordIndex, expected, heard, expectedKey, heardKeys, outcome
    }

    init(
        id: UUID = UUID(),
        wordIndex: Int,
        expected: String,
        heard: String,
        expectedKey: String,
        heardKeys: [String],
        outcome: RecitationOutcome = .skipped
    ) {
        self.id = id
        self.wordIndex = wordIndex
        self.expected = expected
        self.heard = heard
        self.expectedKey = expectedKey
        self.heardKeys = heardKeys
        self.outcome = outcome
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        wordIndex = try container.decode(Int.self, forKey: .wordIndex)
        expected = try container.decode(String.self, forKey: .expected)
        heard = try container.decode(String.self, forKey: .heard)
        expectedKey = try container.decodeIfPresent(String.self, forKey: .expectedKey) ?? ""
        heardKeys = try container.decodeIfPresent([String].self, forKey: .heardKeys) ?? []
        outcome = try container.decodeIfPresent(RecitationOutcome.self, forKey: .outcome) ?? .skipped
    }

    var heardSomething: Bool { !heard.isEmpty }
}

struct RecitationTry: Codable, Hashable, Identifiable {
    var id = UUID()
    var wordIndex: Int
    var expected: String
    var heard: String
    var expectedKey: String
    var heardKeys: [String]
    var accepted: Bool

    enum CodingKeys: String, CodingKey {
        case id, wordIndex, expected, heard, expectedKey, heardKeys, accepted
    }

    init(
        id: UUID = UUID(),
        wordIndex: Int,
        expected: String,
        heard: String,
        expectedKey: String,
        heardKeys: [String],
        accepted: Bool
    ) {
        self.id = id
        self.wordIndex = wordIndex
        self.expected = expected
        self.heard = heard
        self.expectedKey = expectedKey
        self.heardKeys = heardKeys
        self.accepted = accepted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        wordIndex = try container.decode(Int.self, forKey: .wordIndex)
        expected = try container.decode(String.self, forKey: .expected)
        heard = try container.decodeIfPresent(String.self, forKey: .heard) ?? ""
        expectedKey = try container.decodeIfPresent(String.self, forKey: .expectedKey) ?? ""
        heardKeys = try container.decodeIfPresent([String].self, forKey: .heardKeys) ?? []
        accepted = try container.decodeIfPresent(Bool.self, forKey: .accepted) ?? false
    }

    var heardSomething: Bool { !heard.isEmpty }
}

struct RecitationCredit: Codable, Hashable, Identifiable {
    var id = UUID()
    var wordIndex: Int
    var expected: String

    enum CodingKeys: String, CodingKey {
        case id, wordIndex, expected
    }

    init(id: UUID = UUID(), wordIndex: Int, expected: String) {
        self.id = id
        self.wordIndex = wordIndex
        self.expected = expected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        wordIndex = try container.decode(Int.self, forKey: .wordIndex)
        expected = try container.decodeIfPresent(String.self, forKey: .expected) ?? ""
    }
}

struct RecitationWordReview: Identifiable {
    var id: Int { wordIndex }
    var wordIndex: Int
    var expected: String
    var tries: [RecitationTry]
    var miss: RecitationMiss?
    var credited: Bool

    var rejectedTries: [RecitationTry] { tries.filter { !$0.accepted } }

    var isMiss: Bool { miss != nil }

    var isRetried: Bool { !rejectedTries.isEmpty }

    var isPass: Bool { credited && miss == nil }

    var verdict: String {
        if let miss { return miss.outcome.label }
        return credited ? "matched" : "still owed"
    }
}

enum RecitationFilter: String, CaseIterable, Identifiable {
    case misses
    case retries
    case passes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .misses: "Misses"
        case .retries: "Retries"
        case .passes: "Passes"
        }
    }

    var icon: String {
        switch self {
        case .misses: "xmark"
        case .retries: "arrow.clockwise"
        case .passes: "checkmark"
        }
    }

    func admits(_ review: RecitationWordReview) -> Bool {
        switch self {
        case .misses: review.isMiss
        case .retries: review.isRetried
        case .passes: review.isPass
        }
    }
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
    var tries: [RecitationTry]
    var credits: [RecitationCredit]
    var transcript: String

    enum CodingKeys: String, CodingKey {
        case id, chunkID, date, passageTitle, excerpt, expectedCount, matchedCount, misses, tries,
             credits, transcript
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
        tries: [RecitationTry],
        credits: [RecitationCredit],
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
        self.tries = tries
        self.credits = credits
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
        tries = try container.decodeIfPresent([RecitationTry].self, forKey: .tries) ?? []
        credits = try container.decodeIfPresent([RecitationCredit].self, forKey: .credits) ?? []
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript) ?? ""
    }

    var summary: String {
        let missed = misses.isEmpty ? "no misses" : "\(misses.count) missed"
        let rejected = tries.filter { !$0.accepted }.count
        guard rejected > 0 else { return missed }
        return "\(missed) · \(rejected) unheard \(rejected == 1 ? "try" : "tries")"
    }

    var hasDetail: Bool { !misses.isEmpty || !tries.isEmpty || !credits.isEmpty }

    var wordReviews: [RecitationWordReview] {
        var triesByWord: [Int: [RecitationTry]] = [:]
        var expectedByWord: [Int: String] = [:]
        for entry in tries {
            triesByWord[entry.wordIndex, default: []].append(entry)
            expectedByWord[entry.wordIndex] = entry.expected
        }
        var missByWord: [Int: RecitationMiss] = [:]
        for miss in misses {
            missByWord[miss.wordIndex] = miss
            expectedByWord[miss.wordIndex] = miss.expected
        }
        var creditedWords: Set<Int> = []
        for credit in credits {
            creditedWords.insert(credit.wordIndex)
            expectedByWord[credit.wordIndex] = credit.expected
        }
        return expectedByWord.keys.sorted().map { index in
            RecitationWordReview(
                wordIndex: index,
                expected: expectedByWord[index] ?? "",
                tries: triesByWord[index] ?? [],
                miss: missByWord[index],
                credited: creditedWords.contains(index)
            )
        }
    }

    func wordReviews(matching filters: Set<RecitationFilter>) -> [RecitationWordReview] {
        guard !filters.isEmpty else { return wordReviews }
        return wordReviews.filter { review in filters.contains { $0.admits(review) } }
    }
}

struct RecitationDraft {
    var expectedCount: Int
    var matchedCount: Int
    var misses: [RecitationMiss]
    var tries: [RecitationTry]
    var credits: [RecitationCredit]
    var transcript: String

    var isEmpty: Bool { misses.isEmpty && tries.isEmpty && matchedCount == 0 }

    func attempt(chunkID: UUID, passageTitle: String, excerpt: String) -> RecitationAttempt {
        RecitationAttempt(
            chunkID: chunkID,
            passageTitle: passageTitle,
            excerpt: excerpt,
            expectedCount: expectedCount,
            matchedCount: matchedCount,
            misses: misses,
            tries: tries,
            credits: credits,
            transcript: transcript
        )
    }
}
