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
        WordLayoutStore.layout(for: text).words
    }

    private var layout: WordLayout {
        WordLayoutStore.layout(for: expectedText)
    }

    var words: [Substring] {
        layout.words
    }

    var paragraphs: [Range<Int>] {
        layout.paragraphs
    }

    var wordCount: Int { layout.words.count }

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
}

struct Passage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dateAdded: Date
    var author: String?
    var section: String?
    var sourceID: Int?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        title: String,
        dateAdded: Date = Date(),
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dateAdded = dateAdded
        self.author = author
        self.section = section
        self.sourceID = sourceID
        self.isArchived = isArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, dateAdded, author, section, sourceID, isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        section = try container.decodeIfPresent(String.self, forKey: .section)
        sourceID = try container.decodeIfPresent(Int.self, forKey: .sourceID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(section, forKey: .section)
        try container.encodeIfPresent(sourceID, forKey: .sourceID)
        try container.encode(isArchived, forKey: .isArchived)
    }

    var sourcePath: String? {
        if let sourceID, let prayer = PrayerLibrary.prayer(id: sourceID) { return prayer.path }
        guard let section, !section.lowercased().hasPrefix("http") else { return nil }
        return section
    }
}
