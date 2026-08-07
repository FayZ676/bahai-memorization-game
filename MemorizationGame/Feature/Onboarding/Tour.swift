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
        case .openBrowse: "Browse Prayers"
        case .pickPrayer: "Choose a prayer"
        case .addPrayer: "Saving and Memorizing"
        case .importPrayer: "Tap the Plus Button"
        case .openPassage: "Open your passage"
        case .hideWord: "Hiding words"
        case .recite: "Reciting out loud"
        case .merge: "Join what you know"
        case .finished: "That's it"
        }
    }

    var body: Text {
        switch self {
        case .openBrowse: Text("Tap the \(Image(systemName: "book")) button to browse Prayers and Writings.")
        case .pickPrayer: Text("Under 'Prayers' tap 'Opening Words' and choose the first prayer in the list.")
        case .addPrayer:
            Text("Tap the \(Image(systemName: "bookmark")) button to save the prayer for later, or tap the \(Image(systemName: "text.word.spacing")) button to memorize the prayer. Try tapping the \(Image(systemName: "text.word.spacing")) button.")
        case .importPrayer: Text("Tap the \(Image(systemName: "plus")) button at the top right to add it to your library. Each line becomes a section you practise on its own.")
        case .openPassage: Text("Tap it to begin. The bar underneath fills in as more of it lives in memory.")
        case .hideWord: Text("Tap a word to hide it, and tap again to bring it back. Press and glide over words to hide or reveal multiple words at once.")
        case .recite: Text("Tap the \(Image(systemName: "mic")) button at the bottom of the screen and say the hidden word out loud.")
        case .merge: Text("The section is yours. Merge it with the next one and recite longer and longer stretches.")
        case .finished: Text("You're ready to start memorizing for real. The prayer you just added is in your library, right where you left it.")
        }
    }

}

@MainActor
@Observable
final class Tour {
    private(set) var step: TourStep = .openBrowse
    private(set) var isPromptVisible = true

    private var pendingPrompt: Task<Void, Never>?

    private static let promptDelay = Duration.seconds(2)

    func complete(_ completed: TourStep) {
        guard completed.rawValue >= step.rawValue,
              let next = TourStep(rawValue: completed.rawValue + 1) else { return }
        pendingPrompt?.cancel()
        withAnimation(Motion.standard) {
            step = next
            isPromptVisible = false
        }
        pendingPrompt = Task {
            try? await Task.sleep(for: Self.promptDelay)
            guard !Task.isCancelled else { return }
            showPrompt()
        }
    }

    func dismissPrompt() {
        pendingPrompt?.cancel()
        withAnimation(Motion.standard) { isPromptVisible = false }
    }

    func showPrompt() {
        pendingPrompt?.cancel()
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
