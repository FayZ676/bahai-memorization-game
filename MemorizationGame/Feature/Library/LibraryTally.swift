import SwiftUI

struct LibraryTally: View {
    let streak: Int
    let memorized: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            count(streak)
            label("Day Streak")
            Spacer(minLength: Spacing.lg)
            label("Memorized")
            count(memorized)
        }
    }

    private func count(_ value: Int) -> some View {
        Text("\(value)")
            .appFont(Typography.numeral)
            .foregroundStyle(Theme.faint)
            .contentTransition(.numericText())
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .appFont(Typography.footnote)
            .tracking(0.5)
            .foregroundStyle(Theme.faint)
    }
}
