import Foundation

struct ReleaseHighlight: Identifiable {
    let symbol: String
    let title: String
    let text: String

    var id: String { title }
}

struct ReleaseNote: Identifiable {
    let version: String
    let headline: String
    let highlights: [ReleaseHighlight]

    var id: String { version }
}

enum ReleaseNotes {
    static let all: [ReleaseNote] = [
        ReleaseNote(
            version: "1.7",
            headline: "A prayer now reads as one page, with the mic and the progress rail resting on top of it.",
            highlights: [
                ReleaseHighlight(
                    symbol: "arrow.up.and.down",
                    title: "Turn the page",
                    text: "Swipe up past the bottom of a section to move on, down past the top to go back. The rail down the left edge says where you are, and takes you anywhere in the prayer."
                ),
                ReleaseHighlight(
                    symbol: "mic",
                    title: "The mic sits on the page",
                    text: "It no longer claims a strip at the foot of the screen, so the words run the full height and scroll behind it."
                ),
                ReleaseHighlight(
                    symbol: "eye",
                    title: "A look at what's hidden",
                    text: "The eye beside the mic brings the hidden words back for a moment, and says so when there is nothing hidden to show."
                ),
                ReleaseHighlight(
                    symbol: "waveform",
                    title: "Recite whenever you like",
                    text: "Reciting aloud no longer waits for words to be hidden — say a section back at any point and it follows you."
                ),
                ReleaseHighlight(
                    symbol: "text.quote",
                    title: "Titled by its opening words",
                    text: "A prayer with no line breaks used to take its whole text as a title. Every passage is now named by the words it opens with."
                )
            ]
        )
    ]

    static var latest: ReleaseNote? { all.first }

    static func note(for version: String) -> ReleaseNote? {
        all.first { $0.version == version }
    }

    static func unseen(version: String, settings: AppSettings) -> ReleaseNote? {
        guard settings.hasSeenWelcomeTour,
              settings.lastSeenReleaseNotesVersion != version else { return nil }
        return note(for: version)
    }
}
