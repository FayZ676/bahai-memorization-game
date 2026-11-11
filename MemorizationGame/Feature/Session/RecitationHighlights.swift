import CoreGraphics

struct RecitationHighlights {
    private(set) var recited: Set<Int> = []
    private(set) var batchPlace: [Int: Int] = [:]
    private var setAside: Set<Int> = []
    private var shakes = 0
    private var flashing: Int?

    mutating func clear() {
        recited = []
        batchPlace = [:]
        setAside = []
    }

    mutating func putAside(_ index: Int) {
        recited.remove(index)
        setAside.insert(index)
    }

    mutating func recite(_ indices: [Int]) {
        let fresh = Set(indices).subtracting(recited).sorted()
        for (place, index) in fresh.enumerated() { batchPlace[index] = place }
        recited.formUnion(fresh)
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
        passage.recitableIndices(from: start).filter { !recited.contains($0) && !setAside.contains($0) }
    }
}
