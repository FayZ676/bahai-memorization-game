import SwiftUI
import Observation

@MainActor
@Observable
final class SessionHint {
    private(set) var message: String?
    private var token = 0

    private static let dwell = Duration.seconds(2.4)

    func show(_ text: String) {
        token += 1
        let raised = token
        message = text
        Task {
            try? await Task.sleep(for: Self.dwell)
            guard raised == token else { return }
            message = nil
        }
    }

    func dismiss() {
        token += 1
        message = nil
    }
}

struct HintBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .appFont(Typography.caption)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 220)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Theme.rowBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            .allowsHitTesting(false)
    }
}
