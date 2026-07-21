import SwiftUI

struct PrayerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let prayer: Prayer

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Preview", onBack: { dismiss() }) {
                NavigationLink {
                    ImportView(initialTitle: prayer.title, initialContent: prayer.text)
                } label: {
                    Text("Import")
                        .font(Typography.body)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.haptic)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !prayer.heading.isEmpty {
                            Text(prayer.heading)
                                .font(Typography.title)
                                .foregroundStyle(Theme.ink)
                        }
                        HStack(spacing: 6) {
                            Text(prayer.author)
                            Text("·")
                            Text(prayer.primaryTag)
                        }
                        .font(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                    }

                    Text(prayer.text)
                        .font(Typography.verse)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .fadeEdge(color: Theme.bg)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
