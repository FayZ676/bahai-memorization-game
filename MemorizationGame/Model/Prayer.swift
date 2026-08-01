import Foundation

struct Prayer: Decodable, Identifiable, Hashable {
    let id: Int
    let author: String
    let heading: String
    let text: String
    let tags: [String]
    let primaryTag: String
    let collection: String
    let section: String
    let source: String?

    var firstLine: String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    var title: String {
        heading.isEmpty ? firstLine : heading
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
}

enum PrayerLibrary {
    static let all: [Prayer] = load()

    static let collections: [Collection] = buildCollections()

    struct Category: Identifiable, Hashable {
        let name: String
        let prayers: [Prayer]
        var id: String { name }
    }

    struct Section: Identifiable, Hashable {
        let name: String
        let categories: [Category]
        var id: String { name }
        var prayerCount: Int { categories.reduce(0) { $0 + $1.prayers.count } }
    }

    struct Collection: Identifiable, Hashable {
        let name: String
        let sections: [Section]
        var id: String { name }
        var prayerCount: Int { sections.reduce(0) { $0 + $1.prayerCount } }
    }

    private static func load() -> [Prayer] {
        guard let url = Bundle.main.url(forResource: "library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return []
        }
        return decoded.entries
    }

    private static func buildCollections() -> [Collection] {
        groupOrdered(all, by: \.collection).map { name, prayers in
            let sections = groupOrdered(prayers, by: \.section).map { sectionName, sectionPrayers in
                let categories = groupOrdered(sectionPrayers, by: \.primaryTag).map { catName, catPrayers in
                    Category(name: catName, prayers: catPrayers)
                }
                return Section(name: sectionName, categories: categories)
            }
            return Collection(name: name, sections: sections)
        }
    }

    private static func groupOrdered(_ prayers: [Prayer], by key: (Prayer) -> String) -> [(String, [Prayer])] {
        var order: [String] = []
        var buckets: [String: [Prayer]] = [:]
        for prayer in prayers {
            let k = key(prayer)
            if buckets[k] == nil { order.append(k) }
            buckets[k, default: []].append(prayer)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    static func prayer(id: Int) -> Prayer? {
        byID[id]
    }

    static func section(named name: String) -> Section? {
        collections.lazy.compactMap { collection in
            collection.sections.first { $0.name == name }
        }.first
    }

    static func category(named name: String, inSection sectionName: String) -> Category? {
        section(named: sectionName)?.categories.first { $0.name == name }
    }

    static func prayer(matchingTitle title: String, author: String?) -> Prayer? {
        all.first { candidate in
            candidate.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && (author == nil || candidate.author == author)
        }
    }

    private static let byID: [Int: Prayer] = Dictionary(
        all.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    private struct Snapshot: Decodable {
        let entries: [Prayer]
    }
}
