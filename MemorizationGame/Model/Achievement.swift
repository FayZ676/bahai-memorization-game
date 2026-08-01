import Foundation

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let condition: String
    let symbol: String
    let prayerID: Int

    var librarySection: String? {
        PrayerLibrary.prayer(id: prayerID)?.section
    }

    func isEarned(in memorizedPrayerIDs: Set<Int>) -> Bool {
        memorizedPrayerIDs.contains(prayerID)
    }
}

struct AchievementGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let achievements: [Achievement]

    var librarySection: String? {
        achievements.first?.librarySection
    }
}

enum AchievementCatalog {
    enum Entry: Identifiable, Hashable {
        case group(AchievementGroup)
        case standalone(Achievement)

        var id: String {
            switch self {
            case .group(let group): return group.id
            case .standalone(let achievement): return achievement.id
            }
        }

        var achievements: [Achievement] {
            switch self {
            case .group(let group): return group.achievements
            case .standalone(let achievement): return [achievement]
            }
        }

        var librarySection: String? {
            switch self {
            case .group(let group): return group.librarySection
            case .standalone(let achievement): return achievement.librarySection
            }
        }
    }

    static let entries: [Entry] = [
        .group(
            AchievementGroup(
                id: "obligatory-prayer",
                title: "Obligatory Prayer",
                symbol: "hands.and.sparkles",
                achievements: [
                    Achievement(
                        id: "obligatory-short",
                        title: "Short",
                        condition: "Memorize the Short Obligatory Prayer.",
                        symbol: "sun.max",
                        prayerID: 391
                    ),
                    Achievement(
                        id: "obligatory-medium",
                        title: "Medium",
                        condition: "Memorize the Medium Obligatory Prayer.",
                        symbol: "sun.horizon",
                        prayerID: 392
                    ),
                    Achievement(
                        id: "obligatory-long",
                        title: "Long",
                        condition: "Memorize the Long Obligatory Prayer.",
                        symbol: "moon.stars",
                        prayerID: 393
                    )
                ]
            )
        ),
        .standalone(
            Achievement(
                id: "tablet-of-ahmad",
                title: "Tablet of Ahmad",
                condition: "Memorize the Tablet of Ahmad, all 652 words.",
                symbol: "bird",
                prayerID: 386
            )
        )
    ]

    static let all: [Achievement] = entries.flatMap(\.achievements)
}
