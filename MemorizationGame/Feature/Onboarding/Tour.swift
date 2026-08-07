import SwiftUI
import Observation

enum TourStep: Int, CaseIterable {
    case openBrowse
    case pickPrayer
    case addPrayer
    case openPassage
    case hideWord
    case hideSection
    case merge
    case finished

    var title: String {
        switch self {
        case .openBrowse: "Start with a prayer"
        case .pickPrayer: "Choose a prayer"
        case .addPrayer: "Add it to your library"
        case .openPassage: "Open your passage"
        case .hideWord: "Hide a word, then recall it"
        case .hideSection: "Hide the whole section"
        case .merge: "Join what you know"
        case .finished: "That was the real thing"
        }
    }

    var body: String {
        switch self {
        case .openBrowse: "Tap the book to read hundreds of prayers and writings by category, or search for one by name."
        case .pickPrayer: "Under Prayers, tap Opening Words, then tap the first prayer in the list."
        case .addPrayer: "Read it over, then add it. Each line becomes a section you practise on its own."
        case .openPassage: "Tap it to begin. The bar underneath fills in as more of it lives in memory."
        case .hideWord: "Tap a word to hide it, and tap again to bring it back. Press and glide to hide a whole run at once."
        case .hideSection: "Keep hiding until nothing is left, reciting the line from memory as the gaps grow."
        case .merge: "The section is yours. Merge it with the next one and recite longer and longer stretches."
        case .finished: "Every screen you just used was the real app. Nothing here was saved — your library is empty and waiting for the prayer you actually want."
        }
    }

}

@MainActor
@Observable
final class Tour {
    private(set) var step: TourStep = .openBrowse
    private(set) var isPromptVisible = true

    func complete(_ completed: TourStep) {
        guard completed.rawValue >= step.rawValue,
              let next = TourStep(rawValue: completed.rawValue + 1) else { return }
        withAnimation(Motion.standard) {
            step = next
            isPromptVisible = true
        }
    }

    func dismissPrompt() {
        withAnimation(Motion.standard) { isPromptVisible = false }
    }

    func showPrompt() {
        withAnimation(Motion.standard) { isPromptVisible = true }
    }
}

extension EnvironmentValues {
    @Entry var tour: Tour?
}

extension View {
    func completesTourStep(_ step: TourStep) -> some View {
        modifier(TourStepReporter(step: step))
    }
}

private struct TourStepReporter: ViewModifier {
    @Environment(\.tour) private var tour
    let step: TourStep

    func body(content: Content) -> some View {
        content.onAppear { tour?.complete(step) }
    }
}
