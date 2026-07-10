import SwiftUI

struct StreakCard: View {
    @Environment(AppStore.self) private var store

    private static let fillOpacities: [Double] = [0.30, 0.52, 0.74, 1.0]
    private static let fillThresholds = [1, 5, 12, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            counterRow
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.top, 15)
            if store.practicedToday {
                practicedRow
                    .padding(.top, 14)
            } else if let target = store.streakTarget {
                chunkPrompt(target.passage, target.card)
                    .padding(.top, 14)
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.25), value: store.practicedToday)
    }

    private var counterRow: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(store.streakCount)")
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(store.practicedToday ? Theme.accent : Theme.muted)
                    .contentTransition(.numericText())
                Text("Day\nstreak")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.faint)
            }
            Spacer()
            dotStrip
        }
    }

    private var dotStrip: some View {
        let days = store.practiceLog.recentDays(7)
        return HStack(spacing: 6) {
            ForEach(days.indices, id: \.self) { i in
                dot(for: days[i], isToday: i == days.count - 1)
            }
        }
    }

    private func dot(for date: Date, isToday: Bool) -> some View {
        let words = store.practiceLog.words(on: date)
        return Circle()
            .fill(Color.white.opacity(0.07))
            .overlay {
                if words > 0 {
                    Circle().fill(Theme.accent.opacity(Self.fillOpacity(forWords: words)))
                } else if isToday {
                    Circle().strokeBorder(
                        Theme.accent.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [2.4, 2.2])
                    )
                }
            }
            .frame(width: 10, height: 10)
    }

    private static func fillOpacity(forWords words: Int) -> Double {
        let level = fillThresholds.lastIndex { words >= $0 } ?? 0
        return fillOpacities[level]
    }

    private func chunkPrompt(_ passage: Passage, _ card: Reviewable) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(passage.title) · Chunk \(card.span.start)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(card.expectedText)
                .font(.scripture(16))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .padding(.top, 5)
            Text("Practice this chunk")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    NavigationLink(value: passage) { EmptyView() }
                        .opacity(0)
                }
                .padding(.top, 14)
            Text("Practice today to keep the streak alive.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }

    private var practicedRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.bg)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("Practiced today")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                if let target = store.streakTarget {
                    Text(target.card.expectedText)
                        .font(.scripture(14))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
    }
}
