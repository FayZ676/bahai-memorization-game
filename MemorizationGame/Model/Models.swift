import Foundation

struct Passage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dateAdded: Date
    var author: String?
    var section: String?
    var sourceID: Int?
    var isArchived: Bool
    var text: String
    var hiddenWords: Set<Int>
    var lastPracticed: Date?

    init(
        id: UUID = UUID(),
        title: String,
        dateAdded: Date = Date(),
        author: String? = nil,
        section: String? = nil,
        sourceID: Int? = nil,
        isArchived: Bool = false,
        text: String,
        hiddenWords: Set<Int> = [],
        lastPracticed: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.dateAdded = dateAdded
        self.author = author
        self.section = section
        self.sourceID = sourceID
        self.isArchived = isArchived
        self.text = text
        self.hiddenWords = hiddenWords
        self.lastPracticed = lastPracticed
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, dateAdded, author, section, sourceID, isArchived, text, hiddenWords, lastPracticed
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
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        hiddenWords = try container.decodeIfPresent(Set<Int>.self, forKey: .hiddenWords) ?? []
        lastPracticed = try container.decodeIfPresent(Date.self, forKey: .lastPracticed)
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
        try container.encode(text, forKey: .text)
        try container.encode(hiddenWords, forKey: .hiddenWords)
        try container.encodeIfPresent(lastPracticed, forKey: .lastPracticed)
    }

    static func paragraphs(in content: String) -> [String] {
        content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func tokens(in text: String) -> [Substring] {
        WordLayoutStore.layout(for: text).words
    }

    private var layout: WordLayout {
        WordLayoutStore.layout(for: text)
    }

    var words: [Substring] { layout.words }

    var paragraphs: [Range<Int>] { layout.paragraphs }

    var wordCount: Int { layout.words.count }

    var hiddenFraction: Double {
        wordCount > 0 ? Double(hiddenWords.count) / Double(wordCount) : 0
    }

    var isMemorized: Bool {
        wordCount > 0 && hiddenWords.count == wordCount
    }

    func recitableIndices(from start: Int) -> [Int] {
        let owed = hiddenWords.filter { $0 >= start }
        guard owed.isEmpty else { return owed.sorted() }
        return words.indices.filter { $0 >= start && words[$0].contains(where: \.isLetter) }
    }

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

    var sourcePath: String? {
        if let sourceID, let prayer = PrayerLibrary.prayer(id: sourceID) { return prayer.path }
        guard let section, !section.lowercased().hasPrefix("http") else { return nil }
        return section
    }
}
