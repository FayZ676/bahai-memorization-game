import SwiftUI

struct AchievementsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let memorized = store.memorizedPrayerIDs

        Screen {
            ScreenHeader(title: "Achievements", onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    tally(memorized: memorized)

                    ForEach(AchievementCatalog.entries) { entry in
                        switch entry {
                        case .group(let group):
                            GroupSection(group: group, memorized: memorized)
                        case .standalone(let achievement):
                            StandaloneAchievementLink(
                                achievement: achievement,
                                earned: achievement.isEarned(in: memorized)
                            )
                            .cardSurface()
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .fadeEdge(color: Theme.bg)
        }
    }

    private func tally(memorized: Set<Int>) -> some View {
        let earned = AchievementCatalog.all.count { $0.isEarned(in: memorized) }
        return HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(earned)")
                .appFont(Typography.numeral)
                .foregroundStyle(Theme.ink)
            Text("of \(AchievementCatalog.all.count) Earned")
                .appFont(Typography.footnote)
                .tracking(0.5)
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, Spacing.xs)
    }
}

private struct GroupSection: View {
    let group: AchievementGroup
    let memorized: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header

            VStack(spacing: 0) {
                ForEach(Array(group.achievements.enumerated()), id: \.element.id) { index, achievement in
                    if index > 0 {
                        HairlineDivider().padding(.leading, Spacing.lg)
                    }
                    AchievementLink(achievement: achievement, earned: achievement.isEarned(in: memorized))
                }
            }
            .cardSurface()
        }
    }

    @ViewBuilder
    private var header: some View {
        if let section = group.librarySection {
            NavigationLink(value: ImportRoute.section(section)) { headerLabel }
                .buttonStyle(.haptic)
        } else {
            headerLabel
        }
    }

    private var headerLabel: some View {
        let earned = group.achievements.count { $0.isEarned(in: memorized) }
        return HStack(spacing: Spacing.sm) {
            Image(systemName: group.symbol)
                .font(.system(size: 13))
                .foregroundStyle(Theme.faint)
            Text(group.title)
                .appFont(Typography.label)
                .tracking(0.5)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Text("\(earned) of \(group.achievements.count)")
                .appFont(Typography.micro)
                .foregroundStyle(earned > 0 ? Theme.gold : Theme.faint)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, Spacing.xs)
        .contentShape(Rectangle())
    }
}

private struct AchievementLink: View {
    @Environment(AppStore.self) private var store
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        if let passage = store.passage(forPrayerID: achievement.prayerID) {
            NavigationLink(value: passage) { row }
                .buttonStyle(.haptic)
        } else if let prayer = PrayerLibrary.prayer(id: achievement.prayerID) {
            NavigationLink(value: ImportRoute.prayer(prayer)) { row }
                .buttonStyle(.haptic)
        } else {
            row
        }
    }

    private var row: some View {
        AchievementRow(achievement: achievement, earned: earned)
    }
}

private struct StandaloneAchievementLink: View {
    @Environment(AppStore.self) private var store
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        if let passage = store.passage(forPrayerID: achievement.prayerID) {
            NavigationLink(value: passage) { row }
                .buttonStyle(.haptic)
        } else if let section = achievement.librarySection {
            NavigationLink(value: ImportRoute.section(section)) { row }
                .buttonStyle(.haptic)
        } else {
            row
        }
    }

    private var row: some View {
        AchievementRow(achievement: achievement, earned: earned)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        HStack(spacing: Spacing.lg) {
            AchievementBadge(symbol: achievement.symbol, earned: earned)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(achievement.title)
                    .appFont(Typography.passageTitle)
                    .foregroundStyle(earned ? Theme.ink : Theme.muted)

                Text(achievement.condition)
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct AchievementBadge: View {
    let symbol: String
    let earned: Bool
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? Theme.gold.opacity(0.14) : Theme.bg)
                .overlay(
                    Circle().stroke(earned ? Theme.gold.opacity(0.55) : Theme.hairline, lineWidth: 1)
                )

            Image(systemName: earned ? "\(symbol).fill" : symbol)
                .font(.system(size: size * 0.36, weight: .light))
                .foregroundStyle(earned ? Theme.gold : Theme.faint)
                .symbolRenderingMode(.monochrome)
        }
        .frame(width: size, height: size)
    }
}
