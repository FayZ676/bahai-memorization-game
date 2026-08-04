import SwiftUI

struct WritingReader: View {
    let heading: String
    var author: String? = nil
    var attribution: String? = nil
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if !heading.isEmpty {
                        Text(heading)
                            .appFont(Typography.heading)
                            .foregroundStyle(Theme.ink)
                    }
                    if hasAttribution {
                        HStack(spacing: 6) {
                            if let author {
                                Text(author).italic()
                            }
                            if author != nil && attribution != nil {
                                Text("·")
                            }
                            if let attribution {
                                Text(attribution)
                            }
                        }
                        .appFont(Typography.footnote)
                        .foregroundStyle(Theme.faint)
                    }
                }

                Text(text)
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

    private var hasAttribution: Bool { author != nil || attribution != nil }
}
