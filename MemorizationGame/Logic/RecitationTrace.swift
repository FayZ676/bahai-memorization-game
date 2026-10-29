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
    #else
    static func begin() {}
    static func emit(_ stage: String, _ message: @autoclosure () -> String) {}
    #endif
}
