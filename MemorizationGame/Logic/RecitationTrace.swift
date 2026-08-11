import Foundation

enum RecitationTrace {
    #if DEBUG
    nonisolated(unsafe) private static var origin = Date()
    private static let lock = NSLock()

    static func begin() {
        lock.lock()
        origin = Date()
        lock.unlock()
        emit("session", "---- trace begin ----")
    }

    static func emit(_ stage: String, _ message: @autoclosure () -> String) {
        lock.lock()
        let elapsed = Date().timeIntervalSince(origin)
        lock.unlock()
        print(String(format: "[RECITE %8.3f] %-9@ %@", elapsed, stage as NSString, message() as NSString))
    }

    static func measure<T>(_ stage: String, _ label: String, _ work: () throws -> T) rethrows -> T {
        let started = Date()
        let value = try work()
        emit(stage, "\(label) took \(ms(since: started))")
        return value
    }

    static func measure<T>(_ stage: String, _ label: String, _ work: () async throws -> T) async rethrows -> T {
        let started = Date()
        let value = try await work()
        emit(stage, "\(label) took \(ms(since: started))")
        return value
    }

    static func ms(since start: Date) -> String {
        String(format: "%.0fms", Date().timeIntervalSince(start) * 1000)
    }
    #else
    static func begin() {}
    static func emit(_ stage: String, _ message: @autoclosure () -> String) {}

    static func measure<T>(_ stage: String, _ label: String, _ work: () throws -> T) rethrows -> T {
        try work()
    }

    static func measure<T>(_ stage: String, _ label: String, _ work: () async throws -> T) async rethrows -> T {
        try await work()
    }

    static func ms(since start: Date) -> String { "" }
    #endif
}
