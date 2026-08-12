import SwiftUI

struct SendButton: View {
    let title: String
    var sending: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if sending {
                    ProgressView().tint(Theme.bg)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .appIcon(15, weight: .semibold)
                        Text(title)
                            .appFont(Typography.button)
                    }
                    .foregroundStyle(Theme.bg)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(enabled ? Theme.accent : Theme.accentMuted, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.haptic)
        .disabled(!enabled)
    }
}
