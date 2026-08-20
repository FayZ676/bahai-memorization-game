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
