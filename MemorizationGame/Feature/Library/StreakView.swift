import SwiftUI

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
