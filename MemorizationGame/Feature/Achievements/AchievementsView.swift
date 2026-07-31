import SwiftUI

struct AchievementsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen {
            ScreenHeader(title: "Achievements", onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    tally
                    ForEach(AchievementCatalog.all) { achievement in
                        AchievementRow(
                            achievement: achievement,
                            earned: store.isEarned(achievement),
                            dateEarned: store.dateEarned(achievement)
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .fadeEdge(color: Theme.bg)
        }
    }

    private var tally: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(store.earnedAchievementCount)")
                .appFont(Typography.numeral)
                .foregroundStyle(Theme.ink)
            Text("of \(AchievementCatalog.all.count) Earned")
                .appFont(Typography.footnote)
                .tracking(0.5)
                .foregroundStyle(Theme.faint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let earned: Bool
    let dateEarned: Date?

    var body: some View {
        HStack(spacing: Spacing.lg) {
            AchievementArt(achievement: achievement, earned: earned)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(achievement.title)
                    .appFont(Typography.passageTitle)
                    .foregroundStyle(earned ? Theme.ink : Theme.muted)

                Text(earned ? achievement.detail : achievement.lockedHint)
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let dateEarned {
                    Text(dateEarned.formatted(date: .abbreviated, time: .omitted))
                        .appFont(Typography.micro)
                        .foregroundStyle(Theme.gold)
                        .padding(.top, Spacing.hair)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
