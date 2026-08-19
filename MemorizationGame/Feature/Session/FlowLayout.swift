import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8
    var justified = false

    private static let maxStretchPerGap: CGFloat = 2.5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = [Row]()
        var current = Row()
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let added = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if added > maxWidth && !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.add(size, spacing: spacing)
        }
        if !current.items.isEmpty { rows.append(current) }

        let width = justified && maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var y = bounds.minY
        var index = 0
        while index < subviews.count {
            var rowItems = [(Int, CGSize)]()
            var rowWidth: CGFloat = 0
            var rowHeight: CGFloat = 0
            while index < subviews.count {
                let size = subviews[index].sizeThatFits(.unspecified)
                let added = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
                if added > maxWidth && !rowItems.isEmpty { break }
                rowItems.append((index, size))
                rowWidth = added
                rowHeight = max(rowHeight, size.height)
                index += 1
            }
            let gap = gapWidth(rowWidth: rowWidth, maxWidth: maxWidth, items: rowItems.count, lastRow: index >= subviews.count)
            var x = bounds.minX
            for (i, size) in rowItems {
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + gap
            }
            y += rowHeight + lineSpacing
        }
    }

    private func gapWidth(rowWidth: CGFloat, maxWidth: CGFloat, items: Int, lastRow: Bool) -> CGFloat {
        guard justified, !lastRow, items > 1 else { return spacing }
        let slack = maxWidth - rowWidth
        guard slack > 0 else { return spacing }
        return spacing + min(slack / CGFloat(items - 1), spacing * Self.maxStretchPerGap)
    }

    private struct Row {
        var items = [CGSize]()
        var width: CGFloat = 0
        var height: CGFloat = 0
        mutating func add(_ size: CGSize, spacing: CGFloat) {
            width += items.isEmpty ? size.width : spacing + size.width
            height = max(height, size.height)
            items.append(size)
        }
    }
}
