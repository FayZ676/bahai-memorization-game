import SwiftUI

/// The practice streak: the count and its label inline on one baseline. Plain
/// and quiet — no glow, no effects.
struct StreakView: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(count)")
                .font(Typography.numeral)
                .foregroundStyle(Theme.ink)
            Text("Day Streak")
                .font(Typography.footnote)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.faint)
            Spacer(minLength: 0)
        }
    }
}
