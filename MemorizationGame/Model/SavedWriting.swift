import Foundation

struct SavedWriting: Codable, Hashable, Identifiable {
    let id: UUID
    let prayerID: Int?
    var title: String
    var text: String
    var author: String?
    var section: String?
    var savedAt: Date

    init(
        id: UUID = UUID(),
        prayerID: Int? = nil,
        title: String,
        text: String,
        author: String? = nil,
        section: String? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.prayerID = prayerID
        self.title = title
        self.text = text
        self.author = author
        self.section = section
        self.savedAt = savedAt
    }

    init(prayer: Prayer) {
        self.init(
            prayerID: prayer.id,
            title: prayer.title,
            text: prayer.text,
            author: prayer.author,
            section: prayer.source ?? prayer.section
        )
    }

    var isFromLibrary: Bool { prayerID != nil }

    var wordCount: Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
}
