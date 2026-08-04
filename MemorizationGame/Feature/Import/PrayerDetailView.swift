import SwiftUI

struct PrayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let prayer: Prayer

    var body: some View {
        Screen {
            ScreenHeader(title: "Preview", onBack: { dismiss() }, slotWidth: 96) {
                HStack(spacing: Spacing.sm) {
                    Button {
                        Feedback.tap()
                        store.toggleSaved(prayer: prayer)
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)

                    BrowseLink(.importPrayer(prayer.id)) {
                        Text("Memorize")
                            .appFont(Typography.body)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.haptic)
                }
            }
        } content: {
            WritingReader(
                heading: prayer.heading,
                author: prayer.author,
                attribution: prayer.source ?? prayer.primaryTag,
                text: prayer.text
            )
        }
        .completesTourStep(.pickPrayer)
        .onAppear { store.recordRead(prayerID: prayer.id) }
    }

    private var isSaved: Bool { store.isSaved(prayerID: prayer.id) }
}
