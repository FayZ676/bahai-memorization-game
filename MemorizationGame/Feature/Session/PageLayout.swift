import SwiftUI
import UIKit

struct ReadingMetrics: Equatable {
    let textMargin: CGFloat
    let maxStretchPerGap: CGFloat
    let wordSpacing: CGFloat
    let lineSpacing: CGFloat
    let paragraphSpacing: CGFloat
    let fontScale: CGFloat
    let dynamicType: DynamicTypeSize

    init(width: CGFloat, fontScale: CGFloat, dynamicType: DynamicTypeSize = .large) {
        let narrow = width < 390
        textMargin = narrow ? 30 : 42
        maxStretchPerGap = (narrow ? 1.5 : 2.5) * fontScale
        wordSpacing = 7 * fontScale
        lineSpacing = 4 * fontScale
        paragraphSpacing = 26 * fontScale
        self.fontScale = fontScale
        self.dynamicType = dynamicType
    }
}

struct PageLayout {
    struct Paragraph {
        let words: Range<Int>
        let frame: CGRect
    }

    let wordFrames: [CGRect]
    let paragraphs: [Paragraph]
    let size: CGSize
    let font: UIFont

    private static let touchSlop = CGSize(width: 3.5, height: 6)

    init(words: [Substring], paragraphs ranges: [Range<Int>], width: CGFloat, metrics: ReadingMetrics, displayScale: CGFloat) {
        let font = Self.font(scale: metrics.fontScale, dynamicType: metrics.dynamicType)
        let lineHeight = Self.pixelCeil(font.lineHeight, displayScale)
        var frames = [CGRect](repeating: .zero, count: words.count)
        var paragraphs: [Paragraph] = []
        var top: CGFloat = 0
        for range in ranges where !range.isEmpty {
            if !paragraphs.isEmpty { top += metrics.paragraphSpacing }
            let widths = range.map { Self.width(of: words[$0], font: font, displayScale: displayScale) }
            let units = Self.units(in: range, words: words)
            let unitWidths = units.map { unit in unit.map { widths[$0] }.reduce(0, +) }
            var rows: [[Int]] = []
            var row: [Int] = []
            var rowWidth: CGFloat = 0
            for (unit, unitWidth) in unitWidths.enumerated() {
                let added = row.isEmpty ? unitWidth : rowWidth + metrics.wordSpacing + unitWidth
                if added > width, !row.isEmpty {
                    rows.append(row)
                    row = []
                    rowWidth = unitWidth
                } else {
                    rowWidth = added
                }
                row.append(unit)
            }
            if !row.isEmpty { rows.append(row) }
            var y = top
            for (rowNumber, row) in rows.enumerated() {
                let used = row.map { unitWidths[$0] }.reduce(0, +) + metrics.wordSpacing * CGFloat(row.count - 1)
                let gap = Self.gap(
                    slack: width - used,
                    items: row.count,
                    lastRow: rowNumber == rows.count - 1,
                    metrics: metrics
                )
                var x: CGFloat = 0
                for unit in row {
                    for offset in units[unit] {
                        frames[range.lowerBound + offset] = CGRect(x: x, y: y, width: widths[offset], height: lineHeight)
                        x += widths[offset]
                    }
                    x += gap
                }
                y += lineHeight + metrics.lineSpacing
            }
            let height = CGFloat(rows.count) * lineHeight + metrics.lineSpacing * CGFloat(max(rows.count - 1, 0))
            paragraphs.append(Paragraph(words: range, frame: CGRect(x: 0, y: top, width: width, height: height)))
            top += height
        }
        wordFrames = frames
        self.paragraphs = paragraphs
        self.font = font
        size = CGSize(width: width, height: top)
    }

    func wordIndex(at point: CGPoint) -> Int? {
        guard let paragraph = paragraphs.first(where: {
            $0.frame.insetBy(dx: -Self.touchSlop.width, dy: -Self.touchSlop.height).contains(point)
        }) else { return nil }
        return paragraph.words
            .filter { wordFrames[$0].insetBy(dx: -Self.touchSlop.width, dy: -Self.touchSlop.height).contains(point) }
            .min { Self.squaredDistance(from: point, to: wordFrames[$0]) < Self.squaredDistance(from: point, to: wordFrames[$1]) }
    }

    func paragraphIndices(near band: ClosedRange<CGFloat>) -> [Int] {
        paragraphs.indices.filter { paragraphs[$0].frame.maxY >= band.lowerBound && paragraphs[$0].frame.minY <= band.upperBound }
    }

    func paragraphIndex(containing word: Int) -> Int? {
        paragraphs.firstIndex { $0.words.contains(word) }
    }

    func paragraphIndex(atTop offset: CGFloat, tolerance: CGFloat) -> Int? {
        paragraphs.firstIndex { $0.frame.minY >= offset - tolerance }
            ?? paragraphs.lastIndex { $0.frame.minY <= offset }
    }

    func density(of hidden: Set<Int>, samples: Int) -> [Double] {
        guard size.height > 0, samples > 0, !wordFrames.isEmpty else { return [] }
        var hiddenCount = [Double](repeating: 0, count: samples)
        var total = [Double](repeating: 0, count: samples)
        for (index, frame) in wordFrames.enumerated() {
            let bucket = min(Int(frame.midY / size.height * CGFloat(samples)), samples - 1)
            total[bucket] += 1
            if hidden.contains(index) { hiddenCount[bucket] += 1 }
        }
        var raw = (0..<samples).map { total[$0] > 0 ? hiddenCount[$0] / total[$0] : -1 }
        for index in raw.indices where raw[index] < 0 {
            let before: Double? = raw[..<index].last { $0 >= 0 }
            let after: Double? = raw[(index + 1)...].first { $0 >= 0 }
            let low: Double = before ?? after ?? 0
            let high: Double = after ?? before ?? 0
            raw[index] = (low + high) / 2
        }
        return raw.indices.map { index -> Double in
            let window = raw[max(0, index - 1)...min(raw.count - 1, index + 1)]
            let sum: Double = window.reduce(0, +)
            return sum / Double(window.count)
        }
    }

    private static func units(in range: Range<Int>, words: [Substring]) -> [[Int]] {
        var units: [[Int]] = []
        for (offset, index) in range.enumerated() {
            if words[index].hasPrefix("-"), words[index].count > 1, !units.isEmpty {
                units[units.count - 1].append(offset)
            } else {
                units.append([offset])
            }
        }
        return units
    }

    static func font(scale: CGFloat, dynamicType: DynamicTypeSize) -> UIFont {
        let token = Typography.recite
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicType))
        let size = UIFontMetrics(forTextStyle: .body)
            .scaledValue(for: token.size * scale * token.face.opticalScale, compatibleWith: traits)
        return UIFont(name: AppFont.serifName(for: token.weight, italic: token.isItalic), size: size)
            ?? UIFont.systemFont(ofSize: size)
    }

    private static func width(of word: Substring, font: UIFont, displayScale: CGFloat) -> CGFloat {
        let parts = WordView.parts(of: String(word))
        return [parts.lead, parts.core, parts.trail]
            .filter { !$0.isEmpty }
            .map { pixelCeil(($0 as NSString).size(withAttributes: [.font: font]).width, displayScale) }
            .reduce(0, +)
    }

    private static func gap(slack: CGFloat, items: Int, lastRow: Bool, metrics: ReadingMetrics) -> CGFloat {
        guard !lastRow, items > 1, slack > 0 else { return metrics.wordSpacing }
        return metrics.wordSpacing + min(slack / CGFloat(items - 1), metrics.wordSpacing * metrics.maxStretchPerGap)
    }

    private static func pixelCeil(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
        (value * scale).rounded(.up) / scale
    }

    private static func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}
