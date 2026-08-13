import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var faded = false
    @State private var dismissed = false

    private static let starSize = 232.0
    private static let arrival = 0.55
    private static let hold = 0.35
    private static let sweep = 0.95
    private static let rest = 0.45

    var body: some View {
        ZStack {
            Theme.bg
            Image("SplashStar")
                .resizable()
                .scaledToFit()
                .frame(width: Self.starSize, height: Self.starSize)
                .mask { StarFadeMask(progress: faded ? 1 : 0) }
                .scaleEffect(arrived ? 1 : 0.94)
                .opacity(arrived ? 1 : 0)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .task { await run() }
    }

    private func run() async {
        guard !reduceMotion else {
            arrived = true
            faded = true
            try? await Task.sleep(for: .seconds(Self.hold))
            finish()
            return
        }

        withAnimation(.easeOut(duration: Self.arrival)) { arrived = true }
        try? await Task.sleep(for: .seconds(Self.arrival + Self.hold))
        guard !dismissed else { return }

        Feedback.hideTick()
        withAnimation(.easeInOut(duration: Self.sweep)) { faded = true }
        try? await Task.sleep(for: .seconds(Self.sweep + Self.rest))
        finish()
    }

    private func finish() {
        guard !dismissed else { return }
        dismissed = true
        onFinish()
    }
}
