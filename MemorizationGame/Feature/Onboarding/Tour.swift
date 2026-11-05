import SwiftUI
import Observation

enum TourStep: Int, CaseIterable {
    case openBrowse
    case pickPrayer
    case addPrayer
    case openPassage
    case hideMany
    case hideWord
    case recite
    case startAnywhere
    case finished

    var title: String {
        switch self {
        case .openBrowse: "Browsing Prayers"
        case .pickPrayer: "Choosing a Passage"
        case .addPrayer: "Memorizing a Prayer"
        case .openPassage: "Open a Memorization"
        case .hideMany: "Hiding Words (Option 1)"
        case .hideWord: "Hiding Words (Option 2)"
        case .recite: "Reciting Words"
        case .startAnywhere: "Starting Anywhere"
        case .finished: "That's it"
        }
    }

    private static func symbol(_ name: String) -> Text {
        Text(Image(systemName: name))
            .foregroundStyle(Theme.accent)
    }

    var body: Text {
        let symbol = Self.symbol
        return switch self {
        case .openBrowse: Text("Tap the \(symbol("book")) button to browse Prayers and Writings.")
        case .pickPrayer: Text("Choose any one of **The Hidden Words**. They are short, and a good place to begin.")
        case .addPrayer:
            Text("Tap the \(symbol("text.word.spacing")) button to add the prayer to your Memorization Library.")
        case .openPassage: Text("Tap the prayer to start memorizing it.")
        case .hideMany:
            Text("Tap the \(symbol("text.word.spacing")) button to hide a handful of words in the paragraph marked with \u{00B6}. Press and hold the button to choose how many words it should hide.")
        case .hideWord: Text("You can also tap a word directly to hide it. Hidden words look faded, and disappear while you recite. Tap one again to bring it back. Press, hold, and glide over multiple words to hide or reveal them at once.")
        case .recite: Text("Tap the \(symbol("mic")) Recite button and say the prayer out loud. Everything else fades away while you recite. Tap words to show or hide them as you go, and tap off the words to stop.")
        case .startAnywhere:
            Text("Practice starts at the paragraph at the top of the screen. Scroll to any paragraph, or tap the \u{00B6} beside it, to start there. The bar under the buttons is the whole prayer, brighter where more words are hidden. Tap or drag it to jump.")
        case .finished: Text("You're ready to start memorizing.")
        }
    }

    var notes: [TourNote] {
        switch self {
        case .finished:
            [
                TourNote(
                    symbol: "gearshape",
                    text: "Open Settings and tap Show welcome tour to see these instructions again."
                ),
                TourNote(
                    symbol: "envelope",
                    text: "Open Settings and tap Send feedback to share an idea or report a problem."
                )
            ]
        default: []
        }
    }
}

struct TourNote: Identifiable {
    let symbol: String
    let text: String

    var id: String { symbol }
}

@MainActor
@Observable
final class Tour {
    private(set) var step: TourStep = .openBrowse
    private(set) var isPromptVisible = true
    var isPaused = false

    private var pendingPrompt: Task<Void, Never>?

    private static let promptDelay = Duration.seconds(1)

    func complete(_ completed: TourStep, onlyIfCurrent: Bool = false) {
        guard completed.rawValue >= step.rawValue,
              !onlyIfCurrent || completed == step,
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

    var canGoBack: Bool { step != TourStep.allCases.first }

    var canGoForward: Bool { step != TourStep.allCases.last }

    func goBack() {
        move(to: step.rawValue - 1)
    }

    func goForward() {
        move(to: step.rawValue + 1)
    }

    private func move(to index: Int) {
        guard let destination = TourStep(rawValue: index) else { return }
        pendingPrompt?.cancel()
        withAnimation(Motion.standard) {
            step = destination
            isPromptVisible = true
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
    func completesTourStep(_ step: TourStep, onlyIfCurrent: Bool = false) -> some View {
        modifier(TourStepReporter(step: step, onlyIfCurrent: onlyIfCurrent))
    }
}

private struct TourStepReporter: ViewModifier {
    @Environment(\.tour) private var tour
    let step: TourStep
    let onlyIfCurrent: Bool

    func body(content: Content) -> some View {
        content.onAppear { tour?.complete(step, onlyIfCurrent: onlyIfCurrent) }
    }
}
