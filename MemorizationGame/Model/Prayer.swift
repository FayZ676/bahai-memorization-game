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
    let title: String
    let wordCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, author, heading, text, tags, primaryTag, collection, section, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        author = try container.decode(String.self, forKey: .author)
        heading = try container.decode(String.self, forKey: .heading)
        text = try container.decode(String.self, forKey: .text)
        tags = try container.decode([String].self, forKey: .tags)
        primaryTag = try container.decode(String.self, forKey: .primaryTag)
        collection = try container.decode(String.self, forKey: .collection)
        section = try container.decode(String.self, forKey: .section)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        title = heading.isEmpty ? Prayer.firstLine(of: text) : heading
        wordCount = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    private static func firstLine(of text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
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
        let target = matchKey(title)
        let authorKey = author.map(matchKey)
        let candidates = all.filter { authorKey == nil || matchKey($0.author) == authorKey }

        if let byTitle = candidates.first(where: { matchKey($0.title) == target }) {
            return byTitle
        }

        let byTag = candidates.filter { candidate in
            matchKey(candidate.primaryTag) == target || candidate.tags.contains { matchKey($0) == target }
        }
        return byTag.count == 1 ? byTag.first : nil
    }

    private static func matchKey(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        return folded
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static let byID: [Int: Prayer] = Dictionary(
        all.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    private struct Snapshot: Decodable {
        let entries: [Prayer]
    }
}
