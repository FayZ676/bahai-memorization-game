import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

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

        let width = rows.map(\.width).max() ?? 0
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
            var x = bounds.minX
            for (i, size) in rowItems {
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
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
