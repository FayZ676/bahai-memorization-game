import SwiftUI

struct SavedWritingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var body: some View {
        Screen {
            ScreenHeader(title: "Saved", onBack: { dismiss() })
        } content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if store.savedWritings.isEmpty {
                        emptyState
                    } else {
                        OptionSection {
                            ForEach(Array(store.savedWritings.enumerated()), id: \.element.id) { index, writing in
                                BrowseLink(route(for: writing)) {
                                    PassageCard(
                                        title: writing.title,
                                        author: writing.author,
                                        section: writing.sourceLabel,
                                        detail: "\(writing.wordCount) words"
                                    )
                                }
                                .buttonStyle(.haptic)

                                if index < store.savedWritings.count - 1 {
                                    Divider()
                                        .overlay(Theme.hairline)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var emptyState: some View {
        Text("Nothing saved yet.")
            .appFont(Typography.body)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private func route(for writing: SavedWriting) -> BrowseRoute {
        if let prayerID = writing.prayerID {
            return .prayer(prayerID)
        }
        return .savedWriting(writing.id)
    }
}
