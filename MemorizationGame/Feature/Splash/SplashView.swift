import SwiftUI

private struct Breeze {
    var sweep = 0.0
    var scale = 1.0
    var driftX = 0.0
    var driftY = 0.0
}

struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var stirring = false
    @State private var dismissed = false

    private static let starSize = 232.0
    private static let arrival = 0.55
    private static let beat = 0.7
    private static let lift = 0.5
    private static let carry = 0.62
    private static let gust = lift + carry

    var body: some View {
        ZStack {
            Theme.bg
            KeyframeAnimator(initialValue: Breeze(), trigger: stirring) { breeze in
                Image("SplashStar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.starSize, height: Self.starSize)
                    .mask { StarFadeMask(progress: stirring ? breeze.sweep : 0) }
                    .offset(x: stirring ? breeze.driftX : 0, y: stirring ? breeze.driftY : 0)
                    .scaleEffect(arrived ? (stirring ? breeze.scale : 1) : 0.94)
                    .opacity(arrived ? 1 : 0)
            } keyframes: { _ in
                KeyframeTrack(\.sweep) {
                    CubicKeyframe(0.3, duration: Self.lift)
                    CubicKeyframe(1, duration: Self.carry)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.01, duration: Self.lift)
                    CubicKeyframe(1.07, duration: Self.carry)
                }
                KeyframeTrack(\.driftX) {
                    CubicKeyframe(5, duration: Self.lift)
                    CubicKeyframe(30, duration: Self.carry)
                }
                KeyframeTrack(\.driftY) {
                    CubicKeyframe(-2, duration: Self.lift)
                    CubicKeyframe(-16, duration: Self.carry)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            arrived = true
            try? await Task.sleep(for: .seconds(Self.beat))
            finish()
            return
        }

        withAnimation(.easeOut(duration: Self.arrival)) { arrived = true }
        try? await Task.sleep(for: .seconds(Self.arrival + Self.beat))
        guard !dismissed else { return }

        Feedback.cascadeRipple(delays: [0.05, 0.26, 0.47, 0.68, 0.89])
        stirring = true
        try? await Task.sleep(for: .seconds(Self.gust))
        finish()
    }

    private func finish() {
        guard !dismissed else { return }
        dismissed = true
        onFinish()
    }
}
