import SwiftUI

struct RemindersSection: View {
    @Environment(AppStore.self) private var store
    @Binding var permissionDenied: Bool
    @State private var expanded = false

    var body: some View {
        @Bindable var store = store
        return OptionSection(label: "Reminders", icon: "bell", footer: footer) {
            Button {
                withAnimation(Motion.toggle) { expanded.toggle() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("Daily reminders")
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(summary)
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.muted)
                    Image(systemName: "chevron.down")
                        .appIcon(13, weight: .regular)
                        .foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .optionRow()
                .contentShape(Rectangle())
            }
            .buttonStyle(.haptic)

            if expanded {
                HairlineDivider()
                Toggle(isOn: permissionGated(\.reminderEnabled)) {
                    Text("Enabled")
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)
                .optionRow()

                if store.settings.reminderEnabled {
                    ForEach($store.settings.reminders) { reminder in
                        HairlineDivider()
                        row(for: reminder)
                    }
                    HairlineDivider()
                    addButton
                }

                HairlineDivider()
                streakToggle
            }
        }
    }

    private var footer: String? {
        permissionDenied
            ? "Notifications are turned off for this app. Enable them in the Settings app to get reminders."
            : nil
    }

    private var summary: String {
        guard store.settings.reminderEnabled else { return "Off" }
        let count = store.settings.reminders.count
        return count == 1 ? "On" : "\(count) reminders"
    }

    private var addButton: some View {
        Button {
            store.settings.reminders.append(Reminder())
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus")
                    .appIcon(13, weight: .semibold)
                Text("Add reminder")
                    .appFont(Typography.body)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .optionRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
    }

    private var streakToggle: some View {
        Toggle(isOn: permissionGated(\.streakReminderEnabled)) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Streak alerts")
                    .appFont(Typography.body)
                    .foregroundStyle(Theme.ink)
                InfoNote(Typography.label) {
                    Text("A nudge in the evening when your streak is about to end.")
                        .appFont(Typography.label)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .tint(Theme.accent)
        .optionRow()
    }

    private func row(for reminder: Binding<Reminder>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DatePicker(selection: time(of: reminder), displayedComponents: .hourAndMinute) {
                    Text("Time")
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.ink)
                }
                if store.settings.reminders.count > 1 {
                    Button {
                        store.settings.reminders.removeAll { $0.id == reminder.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .appIcon(15)
                            .foregroundStyle(Theme.muted)
                            .padding(.leading, Spacing.md)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.haptic)
                }
            }
            TextField("Reminder message", text: reminder.message, axis: .vertical)
                .appFont(Typography.body)
                .foregroundStyle(Theme.muted)
                .lineLimit(1...4)
                .tint(Theme.accent)
        }
        .optionRow()
    }

    private func permissionGated(_ flag: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.settings[keyPath: flag] },
            set: { enabled in
                guard enabled else {
                    store.settings[keyPath: flag] = false
                    return
                }
                Task {
                    let granted = await ReminderScheduler.requestPermission()
                    store.settings[keyPath: flag] = granted
                    permissionDenied = !granted
                }
            }
        )
    }

    private func time(of reminder: Binding<Reminder>) -> Binding<Date> {
        Binding(
            get: {
                let minute = reminder.wrappedValue.minuteOfDay
                return Calendar.current.date(
                    bySettingHour: minute / 60,
                    minute: minute % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminder.wrappedValue.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
