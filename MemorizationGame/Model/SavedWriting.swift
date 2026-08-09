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
            section: prayer.section
        )
    }

    var sourcePath: String? {
        if let prayerID, let prayer = PrayerLibrary.prayer(id: prayerID) { return prayer.path }
        guard let section, !section.lowercased().hasPrefix("http") else { return nil }
        return section
    }

    var sourceLabel: String? {
        sourcePath?.components(separatedBy: " / ").last
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
}
