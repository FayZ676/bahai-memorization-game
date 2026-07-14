import SwiftUI

struct ChunkOptionsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let vm: SessionViewModel

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ScreenHeader(title: "Options", leading: { Color.clear }, trailing: { Color.clear })

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OptionSection(footer: "How many words the Hide button hides each press. Applies to every chunk.") {
                        HStack(spacing: 12) {
                            Text("Hide Amount")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(store.settings.hideAmount) words")
                                .font(.system(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(Theme.muted)
                            HideAmountStepper(amount: $store.settings.hideAmount)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }

                    OptionSection(footer: "Hides or shows every word in the current chunk.") {
                        actionRow("Hide All Words") { vm.setAllWords(hidden: true) }
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                        actionRow("Show All Words") { vm.setAllWords(hidden: false) }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .presentationDragIndicator(.visible)
    }

    private func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
    }
}

private struct HideAmountStepper: View {
    @Binding var amount: Int

    var body: some View {
        HStack(spacing: 0) {
            step("minus") { amount = max(1, amount - 1) }
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 18)
            step("plus") { amount = min(10, amount + 1) }
        }
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func step(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
    }
}
