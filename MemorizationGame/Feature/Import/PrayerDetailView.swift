import SwiftUI

struct PrayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let prayer: Prayer
    var highlight: Range<Int>? = nil

    var body: some View {
        Screen {
            ScreenHeader(title: "Preview", onBack: { dismiss() }, slotWidth: 84) {
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
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                }
            }
        } content: {
            WritingReader(
                heading: prayer.heading,
                author: prayer.author,
                attribution: prayer.path,
                text: prayer.text,
                highlight: highlight
            )
        }
        .completesTourStep(.pickPrayer)
        .onAppear { store.recordRead(prayerID: prayer.id) }
    }

    private var isSaved: Bool { store.isSaved(prayerID: prayer.id) }
}
