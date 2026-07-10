import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

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

                Section {
                    Toggle("Daily reminder", isOn: reminderEnabled)
                    if store.settings.reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    if permissionDenied {
                        Text("Notifications are turned off for this app. Enable them in the Settings app to get reminders.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(
            get: { store.settings.reminderEnabled },
            set: { enabled in
                guard enabled else {
                    store.settings.reminderEnabled = false
                    return
                }
                Task {
                    let granted = await ReminderScheduler.requestPermission()
                    store.settings.reminderEnabled = granted
                    permissionDenied = !granted
                }
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let minute = store.settings.reminderMinuteOfDay
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.settings.reminderMinuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
