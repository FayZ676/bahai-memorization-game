import SwiftUI

struct PrayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let prayer: Prayer

    var body: some View {
        Screen {
            ScreenHeader(title: "Preview", onBack: { dismiss() }) {
                BrowseLink(.importPrayer(prayer.id)) {
                    Text("Import")
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.haptic)
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !prayer.heading.isEmpty {
                            Text(prayer.heading)
                                .appFont(Typography.heading)
                                .foregroundStyle(Theme.ink)
                        }
                        HStack(spacing: 6) {
                            Text(prayer.author)
                                .italic()
                            Text("·")
                            Text(prayer.source ?? prayer.primaryTag)
                        }
                        .appFont(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                    }

                    Text(prayer.text)
                        .appFont(Typography.verse)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .fadeEdge(color: Theme.bg)
        }
        .completesTourStep(.pickPrayer)
    }
}
