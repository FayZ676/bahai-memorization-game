import SwiftUI

struct RecitationCursor: View {
    let target: CGRect?

    @Environment(\.fontScale) private var fontScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var x: CGFloat = 0
    @State private var top: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var visible = false
    @State private var movedAt = Date()

    private static let width: CGFloat = 2.5
    private static let cornerRadius: CGFloat = 1
    private static let glow: CGFloat = 4
    private static let glowOpacity = 0.85
    private static let halo: CGFloat = 10
    private static let haloOpacity = 0.35
    private static let gap: CGFloat = 3
    private static let trimAboveCap: CGFloat = 6
    private static let trimBelowBaseline: CGFloat = 2
    private static let glide = Animation.spring(response: 0.18, dampingFraction: 0.88)

    var body: some View {
        TimelineView(.animation(paused: !visible || reduceMotion)) { context in
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(Theme.accent)
                .shadow(color: Theme.accent.opacity(Self.glowOpacity), radius: Self.glow)
                .shadow(color: Theme.accent.opacity(Self.haloOpacity), radius: Self.halo)
                .opacity(reduceMotion ? 1 : pulse(at: context.date))
        }
        .frame(width: Self.width, height: height)
        .offset(x: x, y: top)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
        .onChange(of: target) { _, target in
            move(to: target)
        }
        .onAppear { move(to: target) }
    }

    private func pulse(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(movedAt) - Motion.caretHold
        guard elapsed > 0 else { return 1 }
        let phase = (elapsed / Motion.caretPulse).truncatingRemainder(dividingBy: 2)
        let fall = phase < 1 ? phase : 2 - phase
        return 0.5 + 0.5 * cos(.pi * fall)
    }

    private func move(to target: CGRect?) {
        guard let target else {
            withAnimation(.easeOut(duration: 0.22)) { visible = false }
            return
        }
        let unit = fontScale * DynamicTypeScaling.factor(for: dynamicTypeSize)
        let above = Self.trimAboveCap * unit
        let below = Self.trimBelowBaseline * unit
        let caret = CGRect(
            x: target.minX - Self.gap * unit - Self.width / 2,
            y: target.minY + above,
            width: Self.width,
            height: target.height - above - below
        )
        guard !isSettled(on: caret) else { return }
        movedAt = Date()
        let sameLine = abs(caret.minY - top) < 1
        guard visible, sameLine else {
            settle(on: caret)
            if !visible { withAnimation(.easeOut(duration: 0.2)) { visible = true } }
            return
        }
        withAnimation(Self.glide) { settle(on: caret) }
    }

    private func settle(on caret: CGRect) {
        x = caret.minX
        top = caret.minY
        height = caret.height
    }

    private func isSettled(on caret: CGRect) -> Bool {
        visible
            && abs(caret.minX - x) < 0.5
            && abs(caret.minY - top) < 0.5
            && abs(caret.height - height) < 0.5
    }
}
