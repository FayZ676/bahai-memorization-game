import SwiftUI

struct SegmentedPicker<Option: Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    let selected: Option
    let select: (Option) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button {
                    withAnimation(Motion.toggle) { select(option) }
                } label: {
                    Text(label(option))
                        .appFont(Typography.label)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            isSelected ? Theme.accent.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: Radius.inset)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.haptic)
            }
        }
        .padding(3)
    }
}
