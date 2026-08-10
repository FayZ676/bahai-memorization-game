import Foundation

struct TimedToken: Equatable {
    var text: String
    var end: Double
}

struct TranscriptConsumption {
    private var consumedThrough = -Double.greatestFiniteMagnitude

    func pending(in tokens: [TimedToken]) -> [TimedToken] {
        tokens.filter { $0.end > consumedThrough }
    }

    mutating func advance(over tokens: [TimedToken], committed: Int) {
        guard committed > 0, committed <= tokens.count else { return }
        consumedThrough = max(consumedThrough, tokens[committed - 1].end)
    }
}
