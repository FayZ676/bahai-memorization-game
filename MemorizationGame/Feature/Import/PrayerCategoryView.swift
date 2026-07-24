import SwiftUI

struct PrayerCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    let category: PrayerLibrary.Category

    var body: some View {
        Screen {
            ScreenHeader(title: category.name, onBack: { dismiss() })
        } content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    OptionSection {
                        ForEach(Array(category.prayers.enumerated()), id: \.element.id) { index, prayer in
                            NavigationLink(value: ImportRoute.prayer(prayer)) {
                                PrayerRow(prayer: prayer)
                            }
                            .buttonStyle(.haptic)

                            if index < category.prayers.count - 1 {
                                Divider()
                                    .overlay(Theme.hairline)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

struct PrayerRow: View {
    let prayer: Prayer
    var showSection = false

    var body: some View {
        PassageCard(
            title: prayer.title,
            author: prayer.author,
            section: showSection ? prayer.section : nil,
            detail: "\(prayer.wordCount) words"
        )
    }
}
