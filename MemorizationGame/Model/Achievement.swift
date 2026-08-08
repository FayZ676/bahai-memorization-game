import Foundation

enum AchievementRequirement: Hashable {
    case section(String)
    case category(section: String, name: String)
    case collection(name: String, count: Int)

    var count: Int {
        switch self {
        case .section, .category: return 1
        case .collection(_, let count): return count
        }
    }

    var prayerIDs: Set<Int> {
        switch self {
        case .section(let name):
            return ids { $0.section == name }
        case .category(let section, let name):
            return ids { $0.section == section && $0.primaryTag == name }
        case .collection(let name, _):
            return ids { $0.collection == name }
        }
    }

    var route: BrowseRoute {
        switch self {
        case .section(let name): return .section(name)
        case .category(let section, let name): return .category(section: section, name: name)
        case .collection(let name, _): return .collection(name)
        }
    }

    private func ids(matching predicate: (Prayer) -> Bool) -> Set<Int> {
        Set(PrayerLibrary.all.lazy.filter(predicate).map(\.id))
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let condition: String
    let symbol: String
    let requirement: AchievementRequirement

    func matchedCount(in memorizedPrayerIDs: Set<Int>) -> Int {
        memorizedPrayerIDs.intersection(requirement.prayerIDs).count
    }

    func isEarned(in memorizedPrayerIDs: Set<Int>) -> Bool {
        matchedCount(in: memorizedPrayerIDs) >= requirement.count
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "obligatory-prayer",
            title: "Obligatory Prayer",
            condition: "Memorize the Short, Medium, or Long Obligatory Prayer.",
            symbol: "hands.and.sparkles",
            requirement: .section("Obligatory Prayers")
        ),
        Achievement(
            id: "morning-prayer",
            title: "Morning Prayer",
            condition: "Memorize a prayer for the morning.",
            symbol: "sunrise",
            requirement: .category(section: "General Prayers", name: "Morning")
        ),
        Achievement(
            id: "healing-prayer",
            title: "Healing Prayer",
            condition: "Memorize a prayer for healing.",
            symbol: "heart",
            requirement: .category(section: "General Prayers", name: "Healing")
        ),
        Achievement(
            id: "aid-and-assistance-prayer",
            title: "Aid & Assistance Prayer",
            condition: "Memorize a prayer for aid and assistance.",
            symbol: "hand.raised",
            requirement: .category(section: "General Prayers", name: "Aid and Assistance")
        ),
        Achievement(
            id: "family-prayer",
            title: "Family Prayer",
            condition: "Memorize a prayer for the family.",
            symbol: "house",
            requirement: .category(section: "General Prayers", name: "Families")
        ),
        Achievement(
            id: "fasting-prayer",
            title: "Fasting Prayer",
            condition: "Memorize a prayer for the Fast.",
            symbol: "moon",
            requirement: .category(section: "Occasional Prayers", name: "The Fast")
        ),
        Achievement(
            id: "five-hidden-words",
            title: "5 Hidden Words",
            condition: "Memorize five of the Hidden Words.",
            symbol: "book.closed",
            requirement: .collection(name: "The Hidden Words", count: 5)
        )
    ]
}
