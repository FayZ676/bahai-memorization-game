import SwiftUI

struct RecitationCursor: View {
    let target: CGRect?

    @Environment(\.fontScale) private var fontScale

    @State private var leading: CGFloat = 0
    @State private var trailing: CGFloat = 0
    @State private var top: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var visible = false

    private static let sidePad: CGFloat = 4
    private static let trimAboveCap: CGFloat = 6
    private static let trimBelowBaseline: CGFloat = 2
    private static let leadingEdge = Animation.spring(response: 0.15, dampingFraction: 0.86)
    private static let trailingEdge = Animation.spring(response: 0.22, dampingFraction: 0.9)
    private static let lineBreak = Animation.spring(response: 0.24, dampingFraction: 0.86)

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.word, style: .continuous)
            .strokeBorder(Theme.accent, lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: Radius.word, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
            )
            .frame(width: max(trailing - leading, 4), height: height)
            .offset(x: leading, y: top)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .onChange(of: target) { _, target in
                move(to: target)
            }
            .onAppear { move(to: target) }
    }

    private func move(to target: CGRect?) {
        guard let target else {
            withAnimation(.easeOut(duration: 0.22)) { visible = false }
            return
        }
        let sidePad = Self.sidePad * fontScale
        let above = Self.trimAboveCap * fontScale
        let below = Self.trimBelowBaseline * fontScale
        let box = CGRect(
            x: target.minX - sidePad,
            y: target.minY + above,
            width: target.width + sidePad * 2,
            height: target.height - above - below
        )
        guard visible else {
            settle(on: box)
            withAnimation(.easeOut(duration: 0.2)) { visible = true }
            return
        }
        let sameLine = abs(box.minY - top) < 1
        guard !isSettled(on: box) else {
            settle(on: box)
            return
        }
        guard sameLine else {
            withAnimation(Self.lineBreak) { settle(on: box) }
            return
        }
        let forward = box.minX >= leading
        withAnimation(forward ? Self.leadingEdge : Self.trailingEdge) { leading = box.minX }
        withAnimation(forward ? Self.trailingEdge : Self.leadingEdge) { trailing = box.maxX }
        withAnimation(Self.leadingEdge) { height = box.height }
    }

    private func settle(on box: CGRect) {
        leading = box.minX
        trailing = box.maxX
        top = box.minY
        height = box.height
    }

    private func isSettled(on box: CGRect) -> Bool {
        abs(box.minX - leading) < 0.5
            && abs(box.maxX - trailing) < 0.5
            && abs(box.minY - top) < 0.5
            && abs(box.height - height) < 0.5
    }
}
