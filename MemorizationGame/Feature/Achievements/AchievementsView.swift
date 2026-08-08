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

                    VStack(spacing: 0) {
                        ForEach(Array(AchievementCatalog.all.enumerated()), id: \.element.id) { index, achievement in
                            if index > 0 {
                                HairlineDivider().padding(.leading, Spacing.lg)
                            }
                            AchievementLink(achievement: achievement, memorized: memorized)
                        }
                    }
                    .cardSurface()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .fadeEdge(color: Theme.bg)
        }
        .completesTourStep(.achievements, onlyIfCurrent: true)
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

private struct AchievementLink: View {
    @Environment(AppStore.self) private var store
    let achievement: Achievement
    let memorized: Set<Int>

    var body: some View {
        if let passage = store.leadingPassage(for: achievement) {
            NavigationLink(value: passage) { row }
                .buttonStyle(.haptic)
        } else {
            BrowseLink(achievement.requirement.route) { row }
                .buttonStyle(.haptic)
        }
    }

    private var row: some View {
        AchievementRow(
            achievement: achievement,
            earned: achievement.isEarned(in: memorized),
            matched: achievement.matchedCount(in: memorized),
            progress: store.progress(for: achievement)
        )
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let earned: Bool
    let matched: Int
    let progress: Double?

    private var required: Int { achievement.requirement.count }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            AchievementRing(progress: progress, earned: earned)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: earned ? "\(achievement.symbol).fill" : achievement.symbol)
                        .appIcon(15, weight: .light)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(earned ? Theme.gold : Theme.accent)

                    Text(achievement.title)
                        .appFont(Typography.passageTitle)
                        .foregroundStyle(earned ? Theme.ink : Theme.muted)
                }

                Text(achievement.condition)
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if required > 1 && !earned {
                    Text("\(matched) of \(required)")
                        .appFont(Typography.micro)
                        .foregroundStyle(matched > 0 ? Theme.gold : Theme.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .appIcon(13, weight: .semibold)
                .foregroundStyle(Theme.faint)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct AchievementRing: View {
    let progress: Double?
    let earned: Bool
    var size: CGFloat = 52

    private var lineWidth: CGFloat { 4 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ink.opacity(0.1), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: earned ? 1 : min(max(progress ?? 0, 0), 1))
                .stroke(
                    earned ? Theme.gold : Theme.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            center
        }
        .frame(width: size, height: size)
        .animation(Motion.standard, value: progress)
    }

    @ViewBuilder
    private var center: some View {
        if earned {
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(Theme.gold)
        } else if let progress {
            Text("\(ProgressBar.percentValue(progress))")
                .appFont(Typography.label)
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        } else {
            Text("—")
                .appFont(Typography.label)
                .foregroundStyle(Theme.accent)
        }
    }
}
