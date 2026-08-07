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
            ScreenHeader(title: passage.title, onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let path = passage.sourcePath {
                        Text(path)
                            .appFont(Typography.footnote)
                            .foregroundStyle(Theme.faint)
                    }

                    Text(fullText)
                        .appFont(Typography.verse)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let author = passage.author {
                        Colophon(author: author)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .fadeEdge(color: Theme.bg)
        }
    }
}
