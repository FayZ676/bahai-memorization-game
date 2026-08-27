import SwiftUI
import Observation

enum TourStep: Int, CaseIterable {
    case openBrowse
    case pickPrayer
    case addPrayer
    case importPrayer
    case openPassage
    case hideMany
    case hideWord
    case peek
    case recite
    case nextSection
    case achievements
    case finished

    var title: String {
        switch self {
        case .openBrowse: "Browsing Prayers"
        case .pickPrayer: "Choosing a Passage"
        case .addPrayer: "Memorizing a Prayer"
        case .importPrayer: "Importing Prayers"
        case .openPassage: "Open a Memorization"
        case .hideMany: "Hiding Words (Option 1)"
        case .hideWord: "Hiding Words (Option 2)"
        case .peek: "Peeking"
        case .recite: "Reciting Words"
        case .nextSection: "Moving Between Sections"
        case .achievements: "Earning Achievements"
        case .finished: "That's it"
        }
    }

    private static func symbol(_ name: String, size: CGFloat, scale: CGFloat) -> Text {
        Text(Image(systemName: name))
            .font(.system(size: size * scale, weight: .ultraLight))
            .foregroundStyle(Theme.accent)
    }

    func body(scale: CGFloat) -> Text {
        let symbol = { Self.symbol($0, size: Typography.callout.size, scale: scale) }
        return switch self {
        case .openBrowse: Text("Tap the \(symbol("book")) button to browse Prayers and Writings.")
        case .pickPrayer: Text("Choose any one of **The Hidden Words**. They are short, and a good place to begin.")
        case .addPrayer:
            Text("Tap the \(symbol("text.word.spacing")) button to memorize the prayer.")
        case .importPrayer: Text("Tap the \(symbol("plus")) button to add the prayer to your Memorization Library.")
        case .openPassage: Text("Tap the prayer to start memorizing it.")
        case .hideMany:
            Text("Tap the \(symbol("text.word.spacing")) button to hide a handful of words in view at once. Press and hold the button to choose how many words it should hide.")
        case .hideWord: Text("You can also tap a word directly to hide it. Tap it again to bring it back. Press, hold, and glide over multiple words to hide or reveal them at once.")
        case .peek:
            Text("Tap the \(symbol("eye")) button to bring every hidden word back into view. Tap it again to hide them once more.")
        case .recite: Text("Tap the \(symbol("mic")) button to practice saying the words aloud.")
        case .nextSection:
            Text("Paragraphs get split into sections. Swipe up or down to move between sections. You can also tap the progress bar on the left rail.")
        case .achievements:
            Text("Certain prayers earn an achievement once every word is hidden. Tap the \(symbol("chevron.left")) button to return to your Library, then tap the \(symbol("trophy")) button to see them all.")
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
