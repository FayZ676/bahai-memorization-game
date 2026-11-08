import Foundation
import WidgetKit

enum PracticeWidgetFeed {
    private static var pending: Task<Void, Never>?
    private static var published: PracticeSnapshot?
    private static let openingLength = 600

    static func publish(passages: [Passage]) {
        let snapshot = PracticeSnapshot(
            prayer: PracticeQueue.next(passages).map { passage in
                PracticeSnapshot.Prayer(
                    id: passage.id,
                    title: passage.title,
                    opening: String(Passage.paragraphs(in: passage.text).joined(separator: "\n").prefix(openingLength)),
                    hiddenFraction: passage.hiddenFraction,
                    lastPracticed: passage.lastPracticed
                )
            }
        )
        guard snapshot != published else { return }
        published = snapshot
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            snapshot.save()
            WidgetCenter.shared.reloadTimelines(ofKind: PracticeSnapshot.widgetKind)
        }
    }
}
