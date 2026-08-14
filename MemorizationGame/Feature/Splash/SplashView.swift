import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var departed = false
    @State private var dismissed = false

    private static let starSize = 232.0
    private static let arrival = 0.55
    private static let beat = 0.7
    private static let departure = 0.5

    var body: some View {
        ZStack {
            Theme.bg
            Image("SplashStar")
                .resizable()
                .scaledToFit()
                .frame(width: Self.starSize, height: Self.starSize)
                .scaleEffect(scale)
                .opacity(departed ? 0 : (arrived ? 1 : 0))
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .task { await run() }
    }

    private var scale: Double {
        if departed { return 1.04 }
        return arrived ? 1 : 0.94
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

        Feedback.hideTick()
        withAnimation(.easeInOut(duration: Self.departure)) { departed = true }
        try? await Task.sleep(for: .seconds(Self.departure))
        finish()
    }

    private func finish() {
        guard !dismissed else { return }
        dismissed = true
        onFinish()
    }
}
