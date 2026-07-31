import Foundation

struct Achievement: Identifiable, Hashable {
    enum Requirement: Hashable {
        case prayer(id: Int)
        case anyPrayer(tag: String)
        case anyPrayerInSection(String)
    }

    let id: String
    let title: String
    let detail: String
    let lockedHint: String
    let symbol: String
    let artwork: String
    let requirement: Requirement

    func isSatisfied(by memorized: [Prayer]) -> Bool {
        memorized.contains { prayer in
            switch requirement {
            case .prayer(let id):
                return prayer.id == id
            case .anyPrayer(let tag):
                return prayer.primaryTag == tag || prayer.tags.contains(tag)
            case .anyPrayerInSection(let section):
                return prayer.section == section
            }
        }
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "healing-prayer",
            title: "Balm",
            detail: "Memorized a prayer for healing.",
            lockedHint: "Memorize any prayer for healing.",
            symbol: "leaf",
            artwork: "achievement-healing",
            requirement: .anyPrayer(tag: "Healing")
        ),
        Achievement(
            id: "obligatory-prayer",
            title: "Daily Rite",
            detail: "Memorized an obligatory prayer.",
            lockedHint: "Memorize one of the three obligatory prayers.",
            symbol: "sun.horizon",
            artwork: "achievement-obligatory",
            requirement: .anyPrayerInSection("Obligatory Prayers")
        ),
        Achievement(
            id: "tablet-of-ahmad",
            title: "Tablet of Ahmad",
            detail: "Memorized the Tablet of Ahmad.",
            lockedHint: "Memorize the Tablet of Ahmad, all 652 words.",
            symbol: "bird",
            artwork: "achievement-ahmad",
            requirement: .prayer(id: 386)
        )
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}
