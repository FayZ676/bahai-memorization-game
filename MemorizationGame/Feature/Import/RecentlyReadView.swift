import SwiftUI

struct RecentlyReadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var body: some View {
        BrowseList(title: "Recently read", onBack: { dismiss() }) {
            let prayers = store.recentlyReadPrayers
            if prayers.isEmpty {
                EmptyNote("Nothing read yet.")
            } else {
                OptionSection {
                    DividedRows(items: prayers) { prayer in
                        BrowseLink(.prayer(prayer)) {
                            PrayerRow(prayer: prayer, showSection: true)
                        }
                        .buttonStyle(.haptic)
                    }
                }
            }
        }
    }
}
