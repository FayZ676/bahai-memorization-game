import SwiftUI

@MainActor
@Observable
final class RailVisibility {
    private(set) var isShowing = true
    private var idle: Task<Void, Never>?

    private static let linger = Duration.seconds(1.8)
    private static let fade = Animation.easeInOut(duration: 0.28)

    func stir() {
        if !isShowing {
            withAnimation(Self.fade) { isShowing = true }
        }
        restartIdle()
    }

    func hold() {
        idle?.cancel()
        idle = nil
    }

    private func restartIdle() {
        idle?.cancel()
        idle = Task { [weak self] in
            try? await Task.sleep(for: Self.linger)
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        withAnimation(Self.fade) { isShowing = false }
    }
}
