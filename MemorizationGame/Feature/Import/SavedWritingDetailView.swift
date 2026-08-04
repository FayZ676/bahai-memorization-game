import SwiftUI

struct SavedWritingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let writingID: UUID

    var body: some View {
        Screen {
            ScreenHeader(title: "Saved", onBack: { dismiss() }, slotWidth: 96) {
                if let writing {
                    HStack(spacing: Spacing.sm) {
                        Button {
                            Feedback.tap()
                            store.removeSavedWriting(id: writing.id)
                            dismiss()
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.icon)

                        BrowseLink(.importText(title: writing.title, content: writing.text)) {
                            Text("Memorize")
                                .appFont(Typography.body)
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.haptic)
                    }
                }
            }
        } content: {
            if let writing {
                WritingReader(
                    heading: writing.title,
                    author: writing.author,
                    attribution: writing.section,
                    text: writing.text
                )
            } else {
                missingState
            }
        }
    }

    private var writing: SavedWriting? { store.savedWriting(id: writingID) }

    private var missingState: some View {
        VStack {
            Spacer()
            Text("This writing is no longer saved.")
                .appFont(Typography.subtitle)
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
