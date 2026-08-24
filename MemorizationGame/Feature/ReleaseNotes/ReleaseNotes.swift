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
            headline: "A new look, and a faster way to hide words.",
            highlights: [
                ReleaseHighlight(
                    symbol: "textformat",
                    title: "New text",
                    text: "Prayers use a new font, and the lines sit closer together. More of the prayer fits on the screen."
                ),
                ReleaseHighlight(
                    symbol: "minus",
                    title: "A line marks a hidden word",
                    text: "When you hide a word, a line takes its place. Tap any word to hide it. Tap the line to show the word again."
                ),
                ReleaseHighlight(
                    symbol: "eye",
                    title: "See every hidden word",
                    text: "Tap the eye next to the microphone to show all the hidden words. Tap it again to hide them."
                ),
                ReleaseHighlight(
                    symbol: "text.word.spacing",
                    title: "Hide a few words at once",
                    text: "Tap the new button next to the microphone to hide a few of the words on the screen at random. Hold the button to pick how many: 2, 4, 6, 8, or 10."
                ),
                ReleaseHighlight(
                    symbol: "sidebar.squares.leading",
                    title: "The side bar hides itself",
                    text: "The thin bar on the left of a prayer fades out while you read, and comes back when you scroll."
                ),
                ReleaseHighlight(
                    symbol: "book",
                    title: "A sorted library",
                    text: "The prayers you are memorizing sit at the top of the library. The ones you have archived are below them."
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
