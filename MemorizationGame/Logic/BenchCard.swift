#if DEBUG
import Foundation

enum BenchPrayer: String, CaseIterable, Identifiable {
    case shortObligatory = "SOP"
    case family = "FAM"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortObligatory: "Short Obligatory Prayer"
        case .family: "Family Prayer"
        }
    }

    var text: String {
        switch self {
        case .shortObligatory:
            """
            I bear witness, O my God, that Thou hast created me to know Thee and to worship Thee. \
            I testify, at this moment, to my powerlessness and to Thy might, to my poverty and to Thy wealth.

            There is none other God but Thee, the Help in Peril, the Self-Subsisting.
            """
        case .family:
            """
            I beg Thy forgiveness, O my God, and implore pardon after the manner Thou wishest Thy servants \
            to direct themselves to Thee. I beg of Thee to wash away our sins as befitteth Thy Lordship, and \
            to forgive me, my parents, and those who in Thy estimation have entered the abode of Thy love in \
            a manner which is worthy of Thy transcendent sovereignty and well beseemeth the glory of Thy \
            celestial power.

            O my God! Thou hast inspired my soul to offer its supplication to Thee, and but for Thee, I would \
            not call upon Thee. Lauded and glorified art Thou; I yield Thee praise inasmuch as Thou didst \
            reveal Thyself unto me, and I beg Thee to forgive me, since I have fallen short in my duty to know \
            Thee and have failed to walk in the path of Thy love.
            """
        }
    }
}

struct BenchPassage: Identifiable, Hashable {
    let key: String
    let title: String
    let text: String
    let cards: [BenchCard]

    var id: String { key }
}

extension BenchPrayer {
    var passage: BenchPassage {
        BenchPassage(key: rawValue, title: title, text: text, cards: BenchCard.cards(for: self) + [.free])
    }
}

struct BenchCard: Identifiable, Hashable {
    enum Deviation: Hashable {
        case fromMiddle
        case unsaid(anchor: String, offsets: [Int])
        case saidAfterCorrection(anchor: String)
    }

    struct Resolution: Equatable {
        var unsaid: [Int] = []
        var startIndex: Int?
        var anchored: Set<Int> = []
    }

    let id: String
    let prayer: BenchPrayer?
    let instruction: String
    let repeats: Int
    var deviations: [Deviation] = []

    func resolve(in words: [String]) -> Resolution? {
        var resolution = Resolution()
        for deviation in deviations {
            switch deviation {
            case .fromMiddle:
                let start = Self.middleStart(in: words)
                resolution.unsaid += Array(0..<start)
                resolution.startIndex = start
            case .unsaid(let anchor, let offsets):
                guard let range = Self.locate(anchor, in: words) else { return nil }
                resolution.unsaid += offsets.map { range.lowerBound + $0 }
                resolution.anchored.formUnion(range)
            case .saidAfterCorrection(let anchor):
                guard let range = Self.locate(anchor, in: words) else { return nil }
                resolution.anchored.formUnion(range)
            }
        }
        resolution.unsaid.sort()
        return resolution
    }

    static let free = BenchCard(
        id: "F",
        prayer: nil,
        instruction: "Recite the way it went wrong in practice \u{2014} stop, skip, or slip wherever it happened. Then listen back and tap every word you got wrong or left out.",
        repeats: .max
    )

    var isOpenEnded: Bool { repeats == .max }

    static func cards(for prayer: BenchPrayer) -> [BenchCard] {
        catalog.filter { $0.prayer == prayer }
    }

    static func key(_ word: some StringProtocol) -> String {
        String(word.lowercased().filter(\.isLetter))
    }

    private static func locate(_ anchor: String, in words: [String]) -> Range<Int>? {
        let target = anchor.split(separator: " ").map(key)
        let keys = words.map(key)
        guard !target.isEmpty, keys.count >= target.count else { return nil }
        return (0...(keys.count - target.count))
            .first { Array(keys[$0..<($0 + target.count)]) == target }
            .map { $0..<($0 + target.count) }
    }

    private static func middleStart(in words: [String]) -> Int {
        let middle = words.count / 2
        let boundaries: Set<Character> = [".", "!", "?", ";", ":"]
        let starts = words.indices.dropFirst().filter { index in
            guard let last = words[index - 1].last else { return false }
            return boundaries.contains(last)
        }
        let nearest = starts.min { first, second in
            abs(first - middle) < abs(second - middle)
        }
        return nearest ?? middle
    }

    private static let shortObligatory: [BenchCard] = [
        BenchCard(id: "C1", prayer: .shortObligatory, instruction: "Recite as written.", repeats: 3),
        BenchCard(id: "C2", prayer: .shortObligatory, instruction: "Start speaking the instant you tap Record.", repeats: 1),
        BenchCard(id: "C3", prayer: .shortObligatory, instruction: "Somewhere mid-prayer, stop for 3–8 seconds as if recalling, then continue.", repeats: 2),
        BenchCard(id: "C4", prayer: .shortObligatory, instruction: "Partway through, go back to the start of the sentence and say it again.", repeats: 1),
        BenchCard(id: "C5", prayer: .shortObligatory, instruction: "Say \u{201C}um\u{201D} or \u{201C}uh\u{201D} once mid-prayer.", repeats: 1),
        BenchCard(id: "C6", prayer: .shortObligatory, instruction: "Start from the underlined word, not the beginning.", repeats: 1, deviations: [.fromMiddle]),
        BenchCard(id: "S1", prayer: .shortObligatory, instruction: "Say \u{201C}to my might\u{201D} instead of \u{201C}to Thy might\u{201D}.", repeats: 1, deviations: [.unsaid(anchor: "to Thy might", offsets: [1])]),
        BenchCard(id: "S2", prayer: .shortObligatory, instruction: "Say \u{201C}to know me\u{201D} instead of \u{201C}to know Thee\u{201D}.", repeats: 1, deviations: [.unsaid(anchor: "to know Thee", offsets: [2])]),
        BenchCard(id: "S3", prayer: .shortObligatory, instruction: "Say \u{201C}that Thou created\u{201D} — leave out \u{201C}hast\u{201D}.", repeats: 1, deviations: [.unsaid(anchor: "that Thou hast created", offsets: [2])]),
        BenchCard(id: "S4", prayer: .shortObligatory, instruction: "Say \u{201C}to Thy health\u{201D} instead of \u{201C}to Thy wealth\u{201D}.", repeats: 1, deviations: [.unsaid(anchor: "to Thy wealth", offsets: [2])]),
        BenchCard(id: "S5", prayer: .shortObligatory, instruction: "Leave out \u{201C}the Help in Peril\u{201D}.", repeats: 1, deviations: [.unsaid(anchor: "the Help in Peril", offsets: [0, 1, 2, 3])]),
        BenchCard(id: "S6", prayer: .shortObligatory, instruction: "Say \u{201C}to my might — to Thy might\u{201D}.", repeats: 1, deviations: [.saidAfterCorrection(anchor: "to Thy might")]),
        BenchCard(id: "E1", prayer: .shortObligatory, instruction: "Recite as written with a fan or air conditioning running.", repeats: 1),
        BenchCard(id: "E2", prayer: .shortObligatory, instruction: "Recite as written with TV or music playing quietly.", repeats: 1),
        BenchCard(id: "E3", prayer: .shortObligatory, instruction: "Recite as written with the phone flat on a table at arm\u{2019}s length.", repeats: 1),
        BenchCard(id: "E4", prayer: .shortObligatory, instruction: "Recite as written through AirPods.", repeats: 1),
    ]

    private static let family: [BenchCard] = [
        BenchCard(id: "C1", prayer: .family, instruction: "Recite as written.", repeats: 2),
        BenchCard(
            id: "C24",
            prayer: .family,
            instruction: "Start speaking the instant you tap Record. Partway through, go back to the start of a sentence and say it again.",
            repeats: 1
        ),
        BenchCard(
            id: "C35",
            prayer: .family,
            instruction: "Somewhere mid-prayer, stop for 3–8 seconds as if recalling, then continue. Say \u{201C}um\u{201D} or \u{201C}uh\u{201D} once somewhere else.",
            repeats: 1
        ),
        BenchCard(id: "C6", prayer: .family, instruction: "Start from the underlined word, not the beginning.", repeats: 1, deviations: [.fromMiddle]),
        BenchCard(
            id: "FD1",
            prayer: .family,
            instruction: "Four changes: say \u{201C}befitteth my Lordship\u{201D}, leave out \u{201C}my parents\u{201D}, say \u{201C}well befitteth the glory\u{201D}, and say \u{201C}reveal myself — Thyself unto me\u{201D}.",
            repeats: 1,
            deviations: [
                .unsaid(anchor: "befitteth Thy Lordship", offsets: [1]),
                .unsaid(anchor: "me my parents and", offsets: [1, 2]),
                .unsaid(anchor: "well beseemeth the glory", offsets: [1]),
                .saidAfterCorrection(anchor: "reveal Thyself unto me"),
            ]
        ),
        BenchCard(
            id: "FD2",
            prayer: .family,
            instruction: "Four changes: say \u{201C}as Thy Lordship\u{201D} (no \u{201C}befitteth\u{201D}), say \u{201C}I give Thee praise\u{201D}, say \u{201C}reveal myself unto me\u{201D}, and say \u{201C}my duty to know me\u{201D}.",
            repeats: 1,
            deviations: [
                .unsaid(anchor: "as befitteth Thy Lordship", offsets: [1]),
                .unsaid(anchor: "I yield Thee praise", offsets: [1]),
                .unsaid(anchor: "reveal Thyself unto me", offsets: [1]),
                .unsaid(anchor: "to know Thee", offsets: [2]),
            ]
        ),
    ]

    static let catalog = shortObligatory + family
}
#endif
