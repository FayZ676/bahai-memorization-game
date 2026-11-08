import Foundation

struct PracticeSnapshot: Codable, Equatable {
    struct Prayer: Codable, Equatable {
        var id: UUID
        var title: String
        var opening: String
        var hiddenFraction: Double
        var lastPracticed: Date?
    }

    var prayer: Prayer?

    static let appGroup = "group.com.faizififita.MemorizationGame"
    static let widgetKind = "PracticeWidget"
    static let urlScheme = "verses"
    static let passageHost = "passage"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("practice-widget.json")
    }

    static func load() -> PracticeSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PracticeSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func url(forPassage id: UUID) -> URL? {
        URL(string: "\(urlScheme)://\(passageHost)/\(id.uuidString)")
    }

    static func passageID(in url: URL) -> UUID? {
        guard url.scheme == urlScheme, url.host() == passageHost else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
