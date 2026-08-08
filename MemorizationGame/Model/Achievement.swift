import UIKit

enum AchievementRequirement: Hashable {
    case section(String)
    case category(String, in: String)
    case count(Int, from: String)

    var count: Int {
        switch self {
        case .section, .category: return 1
        case .count(let count, _): return count
        }
    }

    var prayerIDs: Set<Int> {
        switch self {
        case .section(let name):
            return ids { $0.section == name }
        case .category(let name, let section):
            return ids { $0.section == section && $0.primaryTag == name }
        case .count(_, let collection):
            return ids { $0.collection == collection }
        }
    }

    var route: BrowseRoute {
        switch self {
        case .section(let name): return .section(name)
        case .category(let name, let section): return .category(section: section, name: name)
        case .count(_, let collection): return .collection(collection)
        }
    }

    private func ids(matching predicate: (Prayer) -> Bool) -> Set<Int> {
        Set(PrayerLibrary.all.lazy.filter(predicate).map(\.id))
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let condition: String
    let requirement: AchievementRequirement

    init(_ title: String, symbol: String, condition: String, requires requirement: AchievementRequirement) {
        self.id = Achievement.slug(title)
        self.title = title
        self.symbol = symbol
        self.condition = condition
        self.requirement = requirement
    }

    func matchedCount(in memorizedPrayerIDs: Set<Int>) -> Int {
        memorizedPrayerIDs.intersection(requirement.prayerIDs).count
    }

    func isEarned(in memorizedPrayerIDs: Set<Int>) -> Bool {
        matchedCount(in: memorizedPrayerIDs) >= requirement.count
    }

    private static func slug(_ title: String) -> String {
        title
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }
}

/// The one place achievements are defined. Every requirement names a section,
/// category or collection exactly as `library.json` spells it, and every symbol
/// needs a `.fill` counterpart for its earned state -- `problems` checks both,
/// and a debug launch trips an assertion rather than shipping an achievement
/// that can never be earned.
enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            "Obligatory Prayer",
            symbol: "hands.and.sparkles",
            condition: "Memorize the Short, Medium, or Long Obligatory Prayer.",
            requires: .section("Obligatory Prayers")
        ),
        Achievement(
            "Morning Prayer",
            symbol: "sunrise",
            condition: "Memorize a prayer for the morning.",
            requires: .category("Morning", in: "General Prayers")
        ),
        Achievement(
            "Healing Prayer",
            symbol: "heart",
            condition: "Memorize a prayer for healing.",
            requires: .category("Healing", in: "General Prayers")
        ),
        Achievement(
            "Aid & Assistance Prayer",
            symbol: "hand.raised",
            condition: "Memorize a prayer for aid and assistance.",
            requires: .category("Aid and Assistance", in: "General Prayers")
        ),
        Achievement(
            "Family Prayer",
            symbol: "house",
            condition: "Memorize a prayer for the family.",
            requires: .category("Families", in: "General Prayers")
        ),
        Achievement(
            "Fasting Prayer",
            symbol: "moon",
            condition: "Memorize a prayer for the Fast.",
            requires: .category("The Fast", in: "Occasional Prayers")
        ),
        Achievement(
            "5 Hidden Words",
            symbol: "book.closed",
            condition: "Memorize five of the Hidden Words.",
            requires: .count(5, from: "The Hidden Words")
        )
    ]

    static var problems: [String] {
        var problems: [String] = []
        var seen: Set<String> = []

        for achievement in all {
            let label = "“\(achievement.title)”"

            if !seen.insert(achievement.id).inserted {
                problems.append("\(label) collides with another achievement’s title.")
            }

            let matches = achievement.requirement.prayerIDs.count
            let needed = achievement.requirement.count
            if needed < 1 {
                problems.append("\(label) requires \(needed) prayers.")
            } else if matches < needed {
                problems.append("\(label) needs \(needed) prayers but its requirement matches \(matches) in library.json.")
            }

            for symbol in [achievement.symbol, "\(achievement.symbol).fill"] where UIImage(systemName: symbol) == nil {
                problems.append("\(label) names a symbol that does not exist: \(symbol).")
            }
        }

        return problems
    }
}
