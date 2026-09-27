struct SilentRecitation {
    private(set) var isActive = false
    private var remaining: [Int] = []

    var cursorIndex: Int? {
        isActive ? remaining.first : nil
    }

    var isFinished: Bool {
        isActive && remaining.isEmpty
    }

    mutating func start(owing indices: [Int]) {
        remaining = indices
        isActive = !indices.isEmpty
    }

    mutating func reveal() -> Int? {
        guard isActive, !remaining.isEmpty else { return nil }
        return remaining.removeFirst()
    }

    mutating func updateOwed(_ indices: [Int]) {
        guard isActive else { return }
        remaining = indices
    }

    mutating func stop() {
        isActive = false
        remaining = []
    }
}
