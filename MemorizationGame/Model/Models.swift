import Foundation

struct Span: Codable, Hashable {
    var start: Int
    var end: Int
}

struct Reviewable: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var passageRef: UUID
    var span: Span
    var expectedText: String
    var hiddenWords: Set<Int>
    var lastPracticed: Date?
    var strength: Double
    var hiddenBaseline: Int

    init(
        id: UUID = UUID(),
        passageRef: UUID,
        span: Span,
        expectedText: String,
        hiddenWords: Set<Int>,
        lastPracticed: Date? = nil,
        strength: Double = 0,
        hiddenBaseline: Int = 0
    ) {
        self.id = id
        self.passageRef = passageRef
        self.span = span
        self.expectedText = expectedText
        self.hiddenWords = hiddenWords
        self.lastPracticed = lastPracticed
        self.strength = strength
        self.hiddenBaseline = hiddenBaseline
    }

    var words: [Substring] { expectedText.split(separator: " ") }
    var wordCount: Int { words.count }

    private enum CodingKeys: String, CodingKey {
        case id, passageRef, span, expectedText, hiddenWords, hiddenWordCount
        case lastPracticed, strength, hiddenBaseline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        passageRef = try container.decode(UUID.self, forKey: .passageRef)
        span = try container.decode(Span.self, forKey: .span)
        expectedText = try container.decode(String.self, forKey: .expectedText)
        if let words = try container.decodeIfPresent(Set<Int>.self, forKey: .hiddenWords) {
            hiddenWords = words
        } else {
            let legacyPrefix = try container.decodeIfPresent(Int.self, forKey: .hiddenWordCount) ?? 0
            hiddenWords = Set(0..<legacyPrefix)
        }
        strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? 0
        hiddenBaseline = try container.decodeIfPresent(Int.self, forKey: .hiddenBaseline) ?? hiddenWords.count
        if let stored = try container.decodeIfPresent(Date.self, forKey: .lastPracticed) {
            lastPracticed = stored
        } else {
            lastPracticed = hiddenWords.isEmpty ? nil : Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(passageRef, forKey: .passageRef)
        try container.encode(span, forKey: .span)
        try container.encode(expectedText, forKey: .expectedText)
        try container.encode(hiddenWords, forKey: .hiddenWords)
        try container.encodeIfPresent(lastPracticed, forKey: .lastPracticed)
        try container.encode(strength, forKey: .strength)
        try container.encode(hiddenBaseline, forKey: .hiddenBaseline)
    }
}

struct Passage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
}
