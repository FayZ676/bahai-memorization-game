import SwiftUI

struct ChunkOptionsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let vm: SessionViewModel

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ScreenHeader(title: "Options", onBack: { dismiss() })

            Form {
                Section {
                    Stepper(value: $store.settings.hideAmount, in: 1...10) {
                        HStack {
                            Text("Hide Amount")
                            Spacer()
                            Text("\(store.settings.hideAmount) words")
                                .foregroundStyle(Theme.muted)
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    Text("How many words the Hide button hides each press. Applies to every chunk.")
                }

                Section {
                    Button("Hide All Words") {
                        vm.setAllWords(hidden: true)
                        dismiss()
                    }
                    Button("Show All Words") {
                        vm.setAllWords(hidden: false)
                        dismiss()
                    }
                } footer: {
                    Text("Hides or shows every word in the current chunk.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
