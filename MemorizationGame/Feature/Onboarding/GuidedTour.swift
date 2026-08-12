import SwiftUI

extension EnvironmentValues {
    @Entry var restartWelcomeTour: () -> Void = {}
}

extension View {
    func guidedTour(
        isActive: Bool,
        onRestart: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) -> some View {
        modifier(GuidedTourModifier(isActive: isActive, onRestart: onRestart, onFinish: onFinish))
    }
}

private struct GuidedTourModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    @State private var tour = Tour()

    let isActive: Bool
    let onRestart: () -> Void
    let onFinish: () -> Void

    func body(content: Content) -> some View {
        content
            .environment(\.tour, isActive ? tour : nil)
            .environment(\.restartWelcomeTour, restart)
            .overlay {
                if isActive {
                    TourOverlay(
                        step: tour.step,
                        isPromptVisible: tour.isPromptVisible,
                        onSkip: close,
                        onDismissPrompt: tour.dismissPrompt,
                        onShowPrompt: tour.showPrompt,
                        onFinish: finish
                    )
                }
            }
            .onChange(of: isActive) { _, active in
                if active { tour = Tour(resumingAt: resumeStep) }
            }
            .onChange(of: tour.step) { _, step in
                guard isActive else { return }
                store.settings.welcomeTourStep = step.rawValue
            }
            .onChange(of: store.passages.count) { _, count in
                if isActive, count > 0 { tour.complete(.importPrayer) }
            }
            .onChange(of: hiddenWordCount) { _, count in
                if isActive, count > 0 { tour.complete(.hideWord) }
            }
    }

    private var hiddenWordCount: Int {
        store.reviewables.reduce(0) { $0 + $1.hiddenWords.count }
    }

    private var resumeStep: TourStep {
        TourStep(rawValue: store.settings.welcomeTourStep) ?? .openBrowse
    }

    private func restart() {
        store.settings.welcomeTourStep = TourStep.openBrowse.rawValue
        tour = Tour()
        onRestart()
    }

    private func close() {
        store.settings.hasSeenWelcomeTour = true
        onFinish()
    }

    private func finish() {
        Feedback.sessionComplete()
        close()
    }
}
