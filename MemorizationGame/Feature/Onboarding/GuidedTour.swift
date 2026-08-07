import SwiftUI

extension View {
    func guidedTour(isActive: Bool, onFinish: @escaping () -> Void) -> some View {
        modifier(GuidedTourModifier(isActive: isActive, onFinish: onFinish))
    }
}

private struct GuidedTourModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    @State private var tour = Tour()

    let isActive: Bool
    let onFinish: () -> Void

    func body(content: Content) -> some View {
        content
            .environment(\.tour, isActive ? tour : nil)
            .overlay {
                if isActive {
                    TourOverlay(
                        step: tour.step,
                        isPromptVisible: tour.isPromptVisible,
                        onSkip: onFinish,
                        onDismissPrompt: tour.dismissPrompt,
                        onShowPrompt: tour.showPrompt,
                        onFinish: finish
                    )
                }
            }
            .onChange(of: isActive) { _, active in
                if active { tour = Tour() }
            }
            .onChange(of: store.passages.count) { _, count in
                if isActive, count > 0 { tour.complete(.importPrayer) }
            }
            .onChange(of: hiddenWordCount) { _, count in
                if isActive, count > 0 { tour.complete(.hideWord) }
            }
            .onChange(of: store.reviewables.count) { old, new in
                if isActive, new < old { tour.complete(.merge) }
            }
            .onChange(of: tour.step) { _, step in
                if isActive, step == .merge, store.reviewables.count < 2 { tour.complete(.merge) }
            }
    }

    private var hiddenWordCount: Int {
        store.reviewables.reduce(0) { $0 + $1.hiddenWords.count }
    }

    private func finish() {
        Feedback.sessionComplete()
        onFinish()
    }
}
