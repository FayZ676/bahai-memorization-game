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
                            Text("Daily reminders")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.accent)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if store.settings.reminderEnabled {
                            ForEach(store.settings.reminders) { reminder in
                                Rectangle()
                                    .fill(Theme.hairline)
                                    .frame(height: 1)
                                reminderRow(reminder)
                            }

                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                            Button(action: addReminder) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Add reminder")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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

    private func reminderRow(_ reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DatePicker(selection: reminderTime(reminder.id), displayedComponents: .hourAndMinute) {
                    Text("Time")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                if store.settings.reminders.count > 1 {
                    Button {
                        removeReminder(reminder.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                            .padding(.leading, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Reminder message", text: reminderMessage(reminder.id), axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .lineLimit(1...4)
                .tint(Theme.accent)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func addReminder() {
        store.settings.reminders.append(Reminder())
    }

    private func removeReminder(_ id: UUID) {
        store.settings.reminders.removeAll { $0.id == id }
    }

    private func reminderMessage(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.settings.reminders.first(where: { $0.id == id })?.message ?? "" },
            set: { newValue in
                guard let index = store.settings.reminders.firstIndex(where: { $0.id == id }) else { return }
                store.settings.reminders[index].message = newValue
            }
        )
    }

    private func reminderTime(_ id: UUID) -> Binding<Date> {
        Binding(
            get: {
                let minute = store.settings.reminders.first(where: { $0.id == id })?.minuteOfDay ?? 0
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                guard let index = store.settings.reminders.firstIndex(where: { $0.id == id }) else { return }
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.settings.reminders[index].minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
