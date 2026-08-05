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
                            BrowseLink(.prayer(prayer)) {
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

struct SearchHitRow: View {
    let hit: SearchHit

    var body: some View {
        if let excerpt = hit.excerpt {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(snippet(excerpt))
                    .appFont(Typography.excerpt)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Spacing.xs) {
                    Text(hit.prayer.title)
                        .lineLimit(1)
                    Text("·")
                    Text(hit.prayer.section)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                }
                .appFont(Typography.footnote)
                .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        } else {
            PrayerRow(prayer: hit.prayer, showSection: true)
        }
    }

    private func snippet(_ excerpt: TextExcerpt) -> AttributedString {
        var attributed = AttributedString(excerpt.snippet)
        let characters = attributed.characters
        guard excerpt.highlightInSnippet.upperBound <= characters.count else { return attributed }
        let start = characters.index(characters.startIndex, offsetBy: excerpt.highlightInSnippet.lowerBound)
        let end = characters.index(start, offsetBy: excerpt.highlightInSnippet.count)
        attributed[start..<end].foregroundColor = Theme.accent
        return attributed
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
