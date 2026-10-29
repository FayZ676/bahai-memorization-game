import CoreGraphics

struct RecitationHighlights {
    private(set) var recited: Set<Int> = []
    private var shakes = 0
    private var flashing: Int?

    mutating func clear() {
        recited = []
    }

    mutating func recite(_ indices: [Int]) {
        recited.formUnion(indices)
    }

    mutating func miss(_ index: Int) {
        shakes += 1
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

    func unattempted(in passage: Passage, from start: Int) -> [Int] {
        passage.recitableIndices(from: start).filter { !recited.contains($0) }
    }
}
