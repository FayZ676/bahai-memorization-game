import SwiftUI

struct StreakCard: View {
    @Environment(AppStore.self) private var store
    let practice: (SessionRoute) -> Void

    var body: some View {
        if let target = store.decayingChunks().first {
            prayerSection(target.passage, target.card, at: Date())
        }
    }

    private func prayerSection(_ passage: Passage, _ card: Reviewable, at now: Date) -> some View {
        let lost = store.decay.wordsLost(card, at: now)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(passage.title) · \(card.span.start)")
                    .font(Typography.subtitle)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(lost) Word\(lost == 1 ? "" : "s") Lost")
                    .font(Typography.callout)
                    .foregroundStyle(Color(hex: 0xA05A2C))
                    .fixedSize()
            }
            Text(card.expectedText)
                .font(Typography.prayer)
                .foregroundStyle(Theme.inkBright)
                .lineSpacing(3)
                .lineLimit(3)
                .padding(.top, 8)
            Button {
                Feedback.tap()
                practice(SessionRoute(passage: passage, focusCardID: card.id))
            } label: {
                Text("Practice This Chunk")
                    .font(Typography.button)
                    .foregroundStyle(Color(hex: 0x1A1206))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xE7B063), Color(hex: 0xD9994C)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }
}
