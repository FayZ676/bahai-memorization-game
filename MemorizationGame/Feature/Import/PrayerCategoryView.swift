import SwiftUI

struct PrayerCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    let category: PrayerLibrary.Category

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: category.name, onBack: { dismiss() })

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    OptionSection {
                        ForEach(Array(category.prayers.enumerated()), id: \.element.id) { index, prayer in
                            NavigationLink {
                                PrayerDetailView(prayer: prayer)
                            } label: {
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
                .padding(16)
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

struct PrayerRow: View {
    let prayer: Prayer
    var showSection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prayer.title)
                .font(Typography.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(prayer.author)
                if showSection {
                    Text("·")
                    Text(prayer.section)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("\(prayer.wordCount) words")
            }
            .font(Typography.footnote)
            .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
