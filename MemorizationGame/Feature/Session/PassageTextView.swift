import SwiftUI

struct PassageTextView: View {
    @Environment(\.dismiss) private var dismiss
    let passage: Passage
    let store: AppStore

    private var fullText: String {
        store.queue(for: passage).map(\.expectedText).joined(separator: "\n\n")
    }

    var body: some View {
        Screen {
            ScreenHeader(title: passage.title, style: .scripture, onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if passage.author != nil || passage.section != nil {
                        HStack(spacing: 6) {
                            if let author = passage.author {
                                Text(author)
                                    .italic()
                            }
                            if passage.author != nil, passage.section != nil {
                                Text("·")
                            }
                            if let section = passage.section {
                                Text(section)
                            }
                        }
                        .appFont(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                    }

                    Text(fullText)
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
    }
}
