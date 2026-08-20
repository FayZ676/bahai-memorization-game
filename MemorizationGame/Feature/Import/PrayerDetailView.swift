import SwiftUI

struct PrayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let prayer: Prayer
    var highlight: Range<Int>? = nil

    var body: some View {
        Screen {
            ScreenHeader(title: "Preview", onBack: { dismiss() }) {
                BrowseLink(.importPrayer(prayer.id)) {
                    Image(systemName: "text.word.spacing")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.icon)
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
    }
}
