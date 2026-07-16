import SwiftUI

struct StreakCard: View {
    @Environment(AppStore.self) private var store
    let practice: (SessionRoute) -> Void

    var body: some View {
        let now = Date()
        let target = store.decayingChunks().first
        return VStack(alignment: .leading, spacing: 0) {
            counterColumn(fade: headerFade(for: target, at: now), at: now)
            if let target {
                HairlineDivider()
                    .padding(.top, 15)
                chunkPrompt(target.passage, target.card)
                    .padding(.top, 14)
            } else if store.hasDecayableChunks {
                HairlineDivider()
                    .padding(.top, 15)
                Text("All chunks fresh")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 12)
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.25), value: store.practicedToday)
    }

    private func headerFade(for target: (passage: Passage, card: Reviewable)?, at now: Date) -> Date? {
        if let target { return store.decay.nextDecay(for: target.card, after: now) }
        if store.hasDecayableChunks { return store.nextFade(at: now) }
        return nil
    }

    private func counterColumn(fade: Date?, at now: Date) -> some View {
        let days = flameDays
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                BurningNumberView(
                    value: store.streakCount,
                    today: days.last ?? FlameDay(words: 0, heat: 0),
                    fontSize: 38
                )
                Text("Day streak")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.faint)
                    .padding(.bottom, 8)
                Spacer(minLength: 8)
                if let fade {
                    fadeCountdown(to: fade, at: now)
                        .padding(.bottom, 8)
                }
            }
            WeekFireView(days: days)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
        }
    }

    private var flameDays: [FlameDay] {
        store.practiceLog.recentDays(7).map {
            FlameDay(words: store.practiceLog.words(on: $0), heat: store.practiceLog.heat(on: $0))
        }
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
            Text("\(lost) word\(lost == 1 ? "" : "s") faded")
                .foregroundStyle(Theme.ember)
                .font(.system(size: 11, weight: .medium))
        }
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
