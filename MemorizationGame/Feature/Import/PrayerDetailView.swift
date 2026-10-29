import SwiftUI

struct PrayerDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.popToLibrary) private var popToLibrary
    @Environment(\.openInLibrary) private var openInLibrary
    let prayer: Prayer
    var highlight: Range<Int>? = nil

    var body: some View {
        Screen {
            ScreenHeader(title: "Preview", onBack: { dismiss() }) {
                Button(action: memorize) {
                    Image(systemName: "text.word.spacing")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.icon)
                .accessibilityLabel("Memorize")
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

    private func memorize() {
        if let existing = store.passages.first(where: { $0.sourceID == prayer.id }) {
            return openInLibrary(existing)
        }
        store.createPassage(
            title: prayer.title,
            text: Passage.paragraphs(in: prayer.text).joined(separator: "\n"),
            author: prayer.author,
            section: prayer.deepestSection,
            sourceID: prayer.id
        )
        popToLibrary()
    }
}
