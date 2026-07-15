import SwiftUI

struct StreakCard: View {
    @Environment(AppStore.self) private var store
    let practice: (SessionRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            counterRow
            if let target = store.decayingChunks().first {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .padding(.top, 15)
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
        let heats = days.map { store.practiceLog.heat(on: $0) }
        return HeatStrip(heats: heats, highlight: days.count - 1)
            .frame(width: 112, height: 10)
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
            Button {
                Feedback.tap()
                practice(SessionRoute(passage: passage, focusCardID: card.id))
            } label: {
                Text("Practice this chunk")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            Text("This passage is fading — review it to lock it back in.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}
