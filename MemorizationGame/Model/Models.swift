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

    init(
        id: UUID = UUID(),
        passageRef: UUID,
        span: Span,
        expectedText: String,
        hiddenWords: Set<Int>
    ) {
        self.id = id
        self.passageRef = passageRef
        self.span = span
        self.expectedText = expectedText
        self.hiddenWords = hiddenWords
    }

    static func tokens(in text: String) -> [Substring] {
        text
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .flatMap(splitInternalHyphens)
    }

    var words: [Substring] {
        Self.tokens(in: expectedText)
    }

    var paragraphs: [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        for paragraph in expectedText.split(separator: "\n", omittingEmptySubsequences: true) {
            let count = Self.tokens(in: String(paragraph)).count
            guard count > 0 else { continue }
            ranges.append(start..<(start + count))
            start += count
        }
        return ranges.isEmpty ? [0..<wordCount] : ranges
    }

    private static func splitInternalHyphens(_ word: Substring) -> [Substring] {
        var pieces: [Substring] = []
        var pieceStart = word.startIndex
        var searchStart = word.startIndex
        while let hyphenIndex = word[searchStart...].firstIndex(of: "-") {
            let afterHyphen = word.index(after: hyphenIndex)
            if hyphenIndex > pieceStart, afterHyphen < word.endIndex {
                pieces.append(word[pieceStart..<hyphenIndex])
                pieceStart = hyphenIndex
            }
            searchStart = afterHyphen
        }
        pieces.append(word[pieceStart...])
        return pieces
    }
    var wordCount: Int { words.count }

    mutating func toggleWord(_ index: Int) {
        if hiddenWords.contains(index) {
            hiddenWords.remove(index)
        } else {
            hiddenWords.insert(index)
        }
    }

    mutating func setAllWords(hidden: Bool) {
        hiddenWords = hidden ? Set(0..<wordCount) : []
    }

    private enum CodingKeys: String, CodingKey {
        case id, passageRef, span, expectedText, hiddenWords, hiddenWordCount
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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(passageRef, forKey: .passageRef)
        try container.encode(span, forKey: .span)
        try container.encode(expectedText, forKey: .expectedText)
        try container.encode(hiddenWords, forKey: .hiddenWords)
    }
}

struct Passage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dateAdded: Date
    var author: String?
    var section: String?
    var sourceID: Int?

    init(
        id: UUID = UUID(),
        title: String,
        dateAdded: Date = Date(),
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.dateAdded = dateAdded
        self.author = author
        self.section = section
        self.sourceID = sourceID
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, dateAdded, author, section, sourceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        author = try container.decodeIfPresent(String.self, forKey: .author)
        section = try container.decodeIfPresent(String.self, forKey: .section)
        sourceID = try container.decodeIfPresent(Int.self, forKey: .sourceID)
    }
}
