import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", onBack: { dismiss() })

            Form {
                Section {
                    Picker("Appearance", selection: $store.settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
