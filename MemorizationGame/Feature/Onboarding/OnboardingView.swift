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
            .overlay {
                TourOverlay(
                    step: tour.step,
                    isPromptVisible: tour.isPromptVisible,
                    onSkip: onFinish,
                    onDismissPrompt: tour.dismissPrompt,
                    onShowPrompt: tour.showPrompt,
                    onFinish: finish
                )
            }
            .onChange(of: sandbox.passages.count) { _, count in
                if count > 0 { tour.complete(.importPrayer) }
            }
            .onChange(of: hiddenWordCount) { _, count in
                if count > 0 { tour.complete(.hideWord) }
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

    private func finish() {
        Feedback.sessionComplete()
        onFinish()
    }
}
