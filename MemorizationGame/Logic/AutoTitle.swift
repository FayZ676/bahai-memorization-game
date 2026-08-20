import Foundation

enum AutoTitle {
    static let wordLimit = 8

    static func from(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        let opening = words.prefix(wordLimit).joined(separator: " ")
        guard words.count > wordLimit else { return opening }
        return opening.trimmingCharacters(in: CharacterSet(charactersIn: ",;:")) + "…"
    }

    static func from(heading: String, text: String) -> String {
        let name = unnumbered(heading)
        guard !name.isEmpty, !text.hasPrefix(name) else { return from(text) }
        return from(name)
    }

    private static func unnumbered(_ heading: String) -> String {
        heading
            .drop(while: \.isNumber)
            .drop { $0 == "." || $0 == " " }
            .trimmingCharacters(in: .whitespaces)
    }
}
