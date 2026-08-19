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
        case .hideWord: "Hiding Words"
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
        case .hideWord: Text("Tap a word to hide it. Tap it again to bring it back. Press and glide over words to hide or reveal multiple words at once.")
        case .recite: Text("Tap the \(symbol("mic")) button to practice saying hidden words aloud.")
        case .nextSection:
            Text("Paragraphs get split into sections. Swipe up the screen to move to the next section, down to go back. Or tap the progress bar above.")
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
