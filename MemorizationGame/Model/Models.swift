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

    var sourcePath: String? {
        if let sourceID, let prayer = PrayerLibrary.prayer(id: sourceID) { return prayer.path }
        guard let section, !section.lowercased().hasPrefix("http") else { return nil }
        return section
    }
}
