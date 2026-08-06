import SwiftUI

struct WritingReader: View {
    @Environment(\.fontScale) private var fontScale
    let heading: String
    var author: String? = nil
    var attribution: String? = nil
    let blocks: [TextBlock]
    let highlight: Range<Int>?

    init(
        heading: String,
        author: String? = nil,
        attribution: String? = nil,
        text: String,
        highlight: Range<Int>? = nil
    ) {
        self.heading = heading
        self.author = author
        self.attribution = attribution
        self.blocks = TextBlock.split(text)
        self.highlight = highlight
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: lineGap) {
                    header
                        .padding(.bottom, 16 - lineGap)

                    ForEach(blocks) { block in
                        blockText(block)
                            .appFont(Typography.verse)
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(lineGap)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(block.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .fadeEdge(color: Theme.bg)
            .task {
                guard let target = highlightedBlock else { return }
                try? await Task.sleep(for: .milliseconds(50))
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private var header: some View {
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
    }

    private func blockText(_ block: TextBlock) -> Text {
        var attributed = AttributedString(block.text)
        applyHighlight(to: &attributed, in: block)
        if block.id == blocks.first?.id {
            applyInitial(to: &attributed)
        }
        return Text(attributed)
    }

    private func applyHighlight(to attributed: inout AttributedString, in block: TextBlock) {
        guard let highlight, let local = block.localRange(of: highlight) else { return }
        let characters = attributed.characters
        guard local.upperBound <= characters.count else { return }
        let start = characters.index(characters.startIndex, offsetBy: local.lowerBound)
        let end = characters.index(start, offsetBy: local.count)
        attributed[start..<end].backgroundColor = Theme.accent.opacity(0.22)
    }

    private func applyInitial(to attributed: inout AttributedString) {
        let characters = attributed.characters
        guard let index = characters.prefix(initialSearchLimit).firstIndex(where: \.isLetter) else { return }
        let next = characters.index(after: index)
        attributed[index..<next].font = Typography.verseInitial.font(scale: fontScale)
    }

    private var highlightedBlock: Int? {
        guard let highlight else { return nil }
        return blocks.first { $0.localRange(of: highlight) != nil }?.id
    }

    private var hasAttribution: Bool { author != nil || attribution != nil }

    private let lineGap: CGFloat = 4
    private let initialSearchLimit = 3
}

struct TextBlock: Identifiable {
    let id: Int
    let text: String
    let range: Range<Int>

    func localRange(of textRange: Range<Int>) -> Range<Int>? {
        let lower = max(range.lowerBound, textRange.lowerBound)
        let upper = min(range.upperBound, textRange.upperBound)
        guard lower < upper else { return nil }
        return (lower - range.lowerBound)..<(upper - range.lowerBound)
    }

    static func split(_ text: String) -> [TextBlock] {
        var blocks: [TextBlock] = []
        var pending: [Substring] = []
        var pendingLength = 0
        var blockStart = 0
        var cursor = 0

        func flush() {
            guard !pending.isEmpty else { return }
            blocks.append(
                TextBlock(
                    id: blocks.count,
                    text: pending.joined(separator: "\n"),
                    range: blockStart..<cursor
                )
            )
            pending = []
            pendingLength = 0
            blockStart = cursor
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            pending.append(line)
            pendingLength += line.count
            cursor += line.count + 1
            if pendingLength >= maxBlockLength { flush() }
        }
        flush()
        return blocks
    }

    private static let maxBlockLength = 1200
}
