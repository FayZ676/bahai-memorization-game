import CoreGraphics

struct RecitationHighlights {
    private(set) var recited: Set<Int> = []
    private(set) var missed: Set<Int> = []
    private var shakes = 0
    private var flashing: Int?

    mutating func clear() {
        recited = []
        missed = []
    }

    mutating func recite(_ indices: [Int]) {
        recited.formUnion(indices)
    }

    mutating func miss(_ index: Int, movedOn: Bool) {
        shakes += 1
        if movedOn { missed.insert(index) }
        flashing = index
    }

    mutating func stopFlashing(_ index: Int) {
        if flashing == index { flashing = nil }
    }

    func isFlashing(_ index: Int) -> Bool {
        flashing == index
    }

    func shakeAmount(at index: Int) -> CGFloat {
        flashing == index ? CGFloat(shakes) : 0
    }

    func unattempted(in card: Reviewable) -> [Int] {
        card.recitableIndices
            .filter { !recited.contains($0) && !missed.contains($0) }
            .sorted()
    }
}
