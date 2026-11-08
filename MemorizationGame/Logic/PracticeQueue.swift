import Foundation

enum PracticeQueue {
    static func next(_ passages: [Passage]) -> Passage? {
        passages
            .filter { !$0.isArchived }
            .min { lhs, rhs in
                let left = lhs.lastPracticed ?? .distantPast
                let right = rhs.lastPracticed ?? .distantPast
                return left != right ? left < right : lhs.dateAdded < rhs.dateAdded
            }
    }
}
