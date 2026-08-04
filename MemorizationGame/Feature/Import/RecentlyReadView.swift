import SwiftUI

struct RecentlyReadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var body: some View {
        Screen {
            ScreenHeader(title: "Recently read", onBack: { dismiss() })
        } content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let prayers = store.recentlyReadPrayers
                    if prayers.isEmpty {
                        emptyState
                    } else {
                        OptionSection {
                            ForEach(Array(prayers.enumerated()), id: \.element.id) { index, prayer in
                                BrowseLink(.prayer(prayer)) {
                                    PrayerRow(prayer: prayer, showSection: true)
                                }
                                .buttonStyle(.haptic)

                                if index < prayers.count - 1 {
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
        Text("Nothing read yet.")
            .appFont(Typography.body)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}
