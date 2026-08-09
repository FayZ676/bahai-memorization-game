import SwiftUI

struct SavedWritingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let writingID: UUID

    var body: some View {
        Screen {
            ScreenHeader(title: "Saved", onBack: { dismiss() }, slotWidth: 84) {
                if let writing {
                    HStack(spacing: Spacing.sm) {
                        Button {
                            store.removeSavedWriting(id: writing.id)
                            dismiss()
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.icon)

                        BrowseLink(.importText(title: writing.title, content: writing.text)) {
                            Image(systemName: "text.word.spacing")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.icon)
                    }
                }
            }
        } content: {
            if let writing {
                WritingReader(
                    heading: writing.title,
                    author: writing.author,
                    attribution: writing.sourcePath,
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
