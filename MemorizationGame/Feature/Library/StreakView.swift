import SwiftUI

/// The practice streak: the count and its label inline on one baseline. Plain
/// and quiet — no glow, no effects.
struct StreakView: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(count)")
                .appFont(Typography.numeral)
                .foregroundStyle(Theme.ink)
            Text("Day Streak")
                .appFont(Typography.footnote)
                .tracking(0.5)
                .foregroundStyle(Theme.faint)
            Spacer(minLength: 0)
        }
    }
}
