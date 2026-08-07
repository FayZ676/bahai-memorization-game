import SwiftUI
import Observation

enum TourStep: Int, CaseIterable {
    case openBrowse
    case pickPrayer
    case addPrayer
    case importPrayer
    case openPassage
    case hideWord
    case recite
    case merge
    case finished

    var title: String {
        switch self {
        case .openBrowse: "Start with a prayer"
        case .pickPrayer: "Choose a prayer"
        case .addPrayer: "Tap the Memorize Button"
        case .importPrayer: "Tap the Plus Button"
        case .openPassage: "Open your passage"
        case .hideWord: "Hiding words"
        case .recite: "Reciting out loud"
        case .merge: "Join what you know"
        case .finished: "That's it"
        }
    }

    var body: String {
        switch self {
        case .openBrowse: "Tap the book to read hundreds of prayers and writings by category, or search for one by name."
        case .pickPrayer: "Under Prayers, tap Opening Words, then tap the first prayer in the list."
        case .addPrayer: "Tap the memorization button at the top right to import the prayer for memorization."
        case .importPrayer: "Tap the plus at the top right to add it to your library. Each line becomes a section you practise on its own."
        case .openPassage: "Tap it to begin. The bar underneath fills in as more of it lives in memory."
        case .hideWord: "Tap a word to hide it, and tap again to bring it back. Press and glide over words to hide or reveal multiple words at once."
        case .recite: "Tap the mic button at the bottom of the screen and say the hidden word out loud."
        case .merge: "The section is yours. Merge it with the next one and recite longer and longer stretches."
        case .finished: "You're ready to start memorizing for real. The prayer you just added is in your library, right where you left it."
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
