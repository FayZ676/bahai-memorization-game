import SwiftUI

struct WritingReader: View {
    let heading: String
    var author: String? = nil
    var attribution: String? = nil
    let blocks: [TextBlock]

    init(heading: String, author: String? = nil, attribution: String? = nil, text: String) {
        self.heading = heading
        self.author = author
        self.attribution = attribution
        self.blocks = TextBlock.split(text)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: lineGap) {
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
                .padding(.bottom, 16 - lineGap)

                ForEach(blocks) { block in
                    Text(block.text)
                        .appFont(Typography.verse)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(lineGap)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .fadeEdge(color: Theme.bg)
    }

    private var hasAttribution: Bool { author != nil || attribution != nil }

    private let lineGap: CGFloat = 4
}

struct TextBlock: Identifiable {
    let id: Int
    let text: String

    static func split(_ text: String) -> [TextBlock] {
        var blocks: [TextBlock] = []
        var pending: [Substring] = []
        var pendingLength = 0

        func flush() {
            guard !pending.isEmpty else { return }
            blocks.append(TextBlock(id: blocks.count, text: pending.joined(separator: "\n")))
            pending = []
            pendingLength = 0
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            pending.append(line)
            pendingLength += line.count
            if pendingLength >= maxBlockLength { flush() }
        }
        flush()
        return blocks
    }

    private static let maxBlockLength = 1200
}
