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
            version: "1.8",
            headline: "New letters, and one clear way to hide a word.",
            highlights: [
                ReleaseHighlight(
                    symbol: "textformat",
                    title: "A new look",
                    text: "The prayers are drawn in a new letter shape, and the lines sit closer together, so you can see more of a prayer at once."
                ),
                ReleaseHighlight(
                    symbol: "minus",
                    title: "A line where a word was",
                    text: "Hide a word and a small line stays in its place. Tap the line to bring the word back, and tap any word to hide it."
                ),
                ReleaseHighlight(
                    symbol: "eye",
                    title: "Look at what is hidden",
                    text: "Tap the eye next to the microphone to see every hidden word. Tap it again, or touch any word, to hide them once more."
                ),
                ReleaseHighlight(
                    symbol: "sidebar.squares.leading",
                    title: "The side bar rests",
                    text: "The thin bar at the left of a prayer fades away while you read, and comes back as soon as you move the page."
                ),
                ReleaseHighlight(
                    symbol: "book",
                    title: "Your prayers in groups",
                    text: "The prayers you are learning now sit together under their own heading, with the ones you have put away below them."
                )
            ]
        ),
        ReleaseNote(
            version: "1.7",
            headline: "Prayers are easier to read and move through.",
            highlights: [
                ReleaseHighlight(
                    symbol: "arrow.up.and.down",
                    title: "Moving through a prayer",
                    text: "Slide the page up to see the next part. Slide it down to go back. The bar on the left of the screen shows you how far along you are, and you can tap it to jump to any part."
                ),
                ReleaseHighlight(
                    symbol: "mic",
                    title: "More room to read",
                    text: "The round buttons now sit on top of the words instead of taking up space below them, so the prayer fills the whole screen."
                ),
                ReleaseHighlight(
                    symbol: "eye",
                    title: "A peek at hidden words",
                    text: "Tap the eye next to the microphone to bring your hidden words back for a moment, then let them go again."
                ),
                ReleaseHighlight(
                    symbol: "waveform",
                    title: "Say it out loud any time",
                    text: "You can read a prayer out loud and have the app listen, even when none of the words are hidden."
                ),
                ReleaseHighlight(
                    symbol: "text.quote",
                    title: "Your list of prayers",
                    text: "The top of your list now counts how many prayers you have memorized, next to the days you have kept going. Prayers are also named after their first few words, so they are easier to tell apart."
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
