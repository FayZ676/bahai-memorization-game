import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var sandbox: AppStore
    @State private var tour = Tour()

    init(settings: AppSettings, onFinish: @escaping () -> Void) {
        _sandbox = State(initialValue: .sandbox(inheriting: settings))
        self.onFinish = onFinish
    }

    var body: some View {
        LibraryView()
            .environment(sandbox)
            .environment(\.tour, tour)
            .overlayPreferenceValue(TourAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    TourOverlay(
                        step: tour.step,
                        spotlight: spotlight(in: anchors, proxy: proxy),
                        size: proxy.size,
                        onSkip: onFinish,
                        onFinish: finish
                    )
                }
                .ignoresSafeArea()
            }
            .onChange(of: sandbox.passages.count) { _, count in
                if count > 0 { tour.complete(.addPrayer) }
            }
            .onChange(of: hiddenWordCount) { _, count in
                if count > 0 { tour.complete(.hideWord) }
            }
            .onChange(of: hasCompletedSection) { _, complete in
                if complete { tour.complete(.hideSection) }
            }
            .onChange(of: sandbox.reviewables.count) { old, new in
                if new < old { tour.complete(.merge) }
            }
            .onChange(of: tour.step) { _, step in
                if step == .merge, sandbox.reviewables.count < 2 { tour.complete(.merge) }
            }
    }

    private var hiddenWordCount: Int {
        sandbox.reviewables.reduce(0) { $0 + $1.hiddenWords.count }
    }

    private var hasCompletedSection: Bool {
        sandbox.reviewables.contains { sandbox.isComplete($0) }
    }

    private func spotlight(in anchors: [TourAnchor: Anchor<CGRect>], proxy: GeometryProxy) -> CGRect? {
        guard let anchor = tour.step.anchor, let bounds = anchors[anchor] else { return nil }
        let rect = proxy[bounds]
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    private func finish() {
        Feedback.sessionComplete()
        onFinish()
    }
}
