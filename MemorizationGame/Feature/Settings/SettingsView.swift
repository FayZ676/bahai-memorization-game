import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OptionSection(label: "Appearance") {
                        appearancePicker
                    }

                    OptionSection(
                        label: "Reminders",
                        footer: permissionDenied
                            ? "Notifications are turned off for this app. Enable them in the Settings app to get reminders."
                            : nil
                    ) {
                        Toggle(isOn: reminderEnabled) {
                            Text("Daily reminder")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.accent)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if store.settings.reminderEnabled {
                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                            DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                                Text("Time")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Message")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                TextField("Reminder message", text: reminderMessage, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1...4)
                                    .tint(Theme.accent)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private var appearancePicker: some View {
        HStack(spacing: 3) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                let selected = store.settings.appearanceMode == mode
                Button {
                    store.settings.appearanceMode = mode
                } label: {
                    Text(mode.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected ? Color.white.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
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

    private var reminderMessage: Binding<String> {
        Binding(
            get: { store.settings.reminderMessage },
            set: { store.settings.reminderMessage = $0 }
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
