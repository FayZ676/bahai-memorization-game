import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false
    @State private var remindersExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OptionSection(label: "Decay speed", footer: store.settings.decayRate.detail) {
                        decayPicker
                    }

                    OptionSection(
                        footer: permissionDenied
                            ? "Notifications are turned off for this app. Enable them in the Settings app to get reminders."
                            : nil
                    ) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { remindersExpanded.toggle() }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Reminders")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(remindersSummary)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.muted)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.faint)
                                    .rotationEffect(.degrees(remindersExpanded ? 180 : 0))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.haptic)

                        if remindersExpanded {
                            HairlineDivider()
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
                                    HairlineDivider()
                                    reminderRow(reminder)
                                }

                                HairlineDivider()
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
                                .buttonStyle(.haptic)
                            }
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

    private var decayPicker: some View {
        HStack(spacing: 3) {
            ForEach(DecayRate.allCases, id: \.self) { rate in
                let selected = store.settings.decayRate == rate
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.settings.decayRate = rate }
                } label: {
                    Text(rate.label)
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
                .buttonStyle(.haptic)
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
                    .buttonStyle(.haptic)
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

    private var remindersSummary: String {
        guard store.settings.reminderEnabled else { return "Off" }
        let count = store.settings.reminders.count
        return count == 1 ? "On" : "\(count) reminders"
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
