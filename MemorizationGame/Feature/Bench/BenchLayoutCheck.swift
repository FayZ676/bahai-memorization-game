#if DEBUG
import SwiftUI
import UIKit

@MainActor
enum BenchLayoutCheck {
    static func run() {
        guard let url = Bundle.main.url(forResource: "library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(Library.self, from: data) else {
            print("layout-check could not read library")
            return
        }
        let scale = UITraitCollection.current.displayScale
        var worstWidth: CGFloat = 0
        var worstHeight: CGFloat = 0
        var measured = 0
        var gaps: [(CGFloat, String, CGFloat, CGFloat)] = []
        for entry in library.entries.prefix(40) {
            let text = entry.text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
            let words = Passage.tokens(in: text)
            let layout = PageLayout(
                words: words,
                paragraphs: WordLayoutStore.layout(for: text).paragraphs,
                width: 10_000,
                metrics: ReadingMetrics(
                    width: 440,
                    fontScale: 1,
                    dynamicType: DynamicTypeSize(UITraitCollection.current.preferredContentSizeCategory) ?? .large
                ),
                displayScale: scale
            )
            for (index, word) in words.enumerated() {
                let host = UIHostingController(
                    rootView: WordView(token: String(word), concealed: false).font(Font(layout.font))
                )
                let size = host.sizeThatFits(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
                worstWidth = max(worstWidth, abs(size.width - layout.wordFrames[index].width))
                gaps.append((size.width - layout.wordFrames[index].width, String(word), size.width, size.height))
                worstHeight = max(worstHeight, abs(size.height - layout.wordFrames[index].height))
                measured += 1
            }
        }
        let over = gaps.filter { abs($0.0) > 0.5 }
        print("layout-check category=\(UITraitCollection.current.preferredContentSizeCategory.rawValue) body scale of 100=\(UIFontMetrics(forTextStyle: .body).scaledValue(for: 100))")
        print("layout-check over-half-point=\(over.count) typical height=\(gaps.first?.3 ?? 0)")
        for gap in gaps.sorted(by: { abs($0.0) > abs($1.0) }).prefix(12) {
            print("layout-check gap \(gap.0) word \(gap.1) drawn \(gap.2)x\(gap.3)")
        }
        print("layout-check words=\(measured) worst width gap=\(worstWidth) worst height gap=\(worstHeight)")
    }

    private struct Library: Decodable {
        struct Entry: Decodable { let text: String }
        let entries: [Entry]
    }
}
#endif
