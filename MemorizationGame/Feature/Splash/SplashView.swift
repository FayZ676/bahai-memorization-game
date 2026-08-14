import SwiftUI

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
    private static let settle = 0.12

    var body: some View {
        ZStack {
            Theme.bg
            KeyframeAnimator(initialValue: 0.0, trigger: stirring) { sweep in
                Image("SplashStar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.starSize, height: Self.starSize)
                    .mask { StarFadeMask(progress: stirring ? sweep : 0) }
                    .scaleEffect(arrived ? 1 : 0.94)
                    .opacity(arrived ? 1 : 0)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.3, duration: Self.lift)
                    CubicKeyframe(1, duration: Self.carry)
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
        try? await Task.sleep(for: .seconds(Self.gust + Self.settle))
        finish()
    }

    private func finish() {
        guard !dismissed else { return }
        dismissed = true
        onFinish()
    }
}
