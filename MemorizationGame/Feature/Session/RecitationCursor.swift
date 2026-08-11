import SwiftUI

struct RecitationCursor: View {
    let target: CGRect?

    @State private var leading: CGFloat = 0
    @State private var trailing: CGFloat = 0
    @State private var baseline: CGFloat = 0
    @State private var visible = false

    private static let leadingEdge = Animation.spring(response: 0.24, dampingFraction: 0.82)
    private static let trailingEdge = Animation.spring(response: 0.42, dampingFraction: 0.9)
    private static let lineBreak = Animation.spring(response: 0.34, dampingFraction: 0.86)

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.line, style: .continuous)
            .fill(Theme.accent)
            .frame(width: max(trailing - leading, 4), height: 2)
            .shadow(color: Theme.accent.opacity(0.35), radius: 4, y: 1)
            .offset(x: leading, y: baseline)
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
        let line = target.maxY + 1
        guard visible else {
            leading = target.minX
            trailing = target.maxX
            baseline = line
            withAnimation(.easeOut(duration: 0.2)) { visible = true }
            return
        }
        let settled = abs(target.minX - leading) < 0.5
            && abs(target.maxX - trailing) < 0.5
            && abs(line - baseline) < 0.5
        guard !settled else {
            leading = target.minX
            trailing = target.maxX
            baseline = line
            return
        }
        guard abs(line - baseline) < 1 else {
            withAnimation(Self.lineBreak) {
                leading = target.minX
                trailing = target.maxX
                baseline = line
            }
            return
        }
        let forward = target.minX >= leading
        withAnimation(forward ? Self.leadingEdge : Self.trailingEdge) { leading = target.minX }
        withAnimation(forward ? Self.trailingEdge : Self.leadingEdge) { trailing = target.maxX }
    }
}
