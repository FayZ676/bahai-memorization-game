import SwiftUI

struct MergeChip: View {
    var filled: Bool = false

    var body: some View {
        Text("Merge")
            .appFont(Typography.micro)
            .tracking(0.5)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 3)
            .background {
                if filled {
                    Capsule().fill(Theme.rowBg)
                }
            }
            .background(Capsule().stroke(Theme.accent.opacity(0.55), lineWidth: 1))
            .contentShape(Capsule())
    }
}
