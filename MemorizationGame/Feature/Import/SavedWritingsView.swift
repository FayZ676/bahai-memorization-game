import SwiftUI

struct SavedWritingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var body: some View {
        BrowseList(title: "Saved", onBack: { dismiss() }) {
            if store.savedWritings.isEmpty {
                EmptyNote("Nothing saved yet.")
            } else {
                OptionSection {
                    DividedRows(items: store.savedWritings) { writing in
                        BrowseLink(route(for: writing)) {
                            PassageCard(
                                title: writing.title,
                                author: writing.author,
                                section: writing.sourceLabel,
                                detail: "\(writing.wordCount) words"
                            )
                        }
                        .buttonStyle(.haptic)
                    }
                }
            }
        }
    }

    private func route(for writing: SavedWriting) -> BrowseRoute {
        if let prayerID = writing.prayerID {
            return .prayer(prayerID)
        }
        return .savedWriting(writing.id)
    }
}
