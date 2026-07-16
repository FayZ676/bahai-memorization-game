import SwiftUI

struct StreakCard: View {
    @Environment(AppStore.self) private var store
    let practice: (SessionRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            counterRow
            if let target = store.decayingChunks().first {
                HairlineDivider()
                    .padding(.top, 15)
                chunkPrompt(target.passage, target.card)
                    .padding(.top, 14)
            } else if store.hasDecayableChunks, let next = store.nextFade() {
                HairlineDivider()
                    .padding(.top, 15)
                restingCountdown(to: next, at: Date())
                    .padding(.top, 12)
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
        let now = Date()
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(passage.title) · Chunk \(card.span.start)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(card.expectedText)
                .font(.scripture(16))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .padding(.top, 5)
            decayIndicator(card, at: now)
                .padding(.top, 12)
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
        }
    }

    private func decayIndicator(_ card: Reviewable, at now: Date) -> some View {
        let lost = store.decay.wordsLost(card, at: now)
        let fraction = store.decay.lostFraction(card, at: now)
        let next = store.decay.nextDecay(for: card, after: now)
        return VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface)
                    Capsule()
                        .fill(Theme.ember)
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 3 : 0))
                }
            }
            .frame(height: 3)
            HStack(spacing: 0) {
                Text("\(lost) word\(lost == 1 ? "" : "s") faded")
                    .foregroundStyle(Theme.ember)
                Spacer()
                if let next {
                    fadeCountdown(to: next, at: now)
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
    }

    private func restingCountdown(to next: Date, at now: Date) -> some View {
        HStack(spacing: 0) {
            Text("All chunks fresh")
                .foregroundStyle(Theme.muted)
            Spacer()
            fadeCountdown(to: next, at: now)
        }
        .font(.system(size: 11, weight: .medium))
    }

    private func fadeCountdown(to next: Date, at now: Date) -> some View {
        HStack(spacing: 4) {
            Text("Next fade in")
                .foregroundStyle(Theme.faint)
            Text(timerInterval: min(now, next)...next, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }
}
