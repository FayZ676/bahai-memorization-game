import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tour) private var tour
    @State private var permissionDenied = false
    @State private var remindersExpanded = false
    @State private var replayOnboarding = false

    var body: some View {
        Screen {
            ScreenHeader(title: "Settings", onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OptionSection(label: "Appearance") {
                        themePicker
                    }

                    OptionSection(label: "Text Size") {
                        fontSizePicker
                    }

                    OptionSection(
                        label: "Reminders",
                        footer: permissionDenied
                            ? "Notifications are turned off for this app. Enable them in the Settings app to get reminders."
                            : nil
                    ) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { remindersExpanded.toggle() }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Daily reminders")
                                    .appFont(Typography.body)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(remindersSummary)
                                    .appFont(Typography.body)
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
                                Text("Enabled")
                                    .appFont(Typography.body)
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
                                            .appFont(Typography.body)
                                    }
                                    .foregroundStyle(Theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.haptic)
                            }

                            HairlineDivider()
                            Toggle(isOn: streakReminderEnabled) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Streak alerts")
                                        .appFont(Typography.body)
                                        .foregroundStyle(Theme.ink)
                                    Text("A nudge in the evening when your streak is about to end.")
                                        .appFont(Typography.label)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .tint(Theme.accent)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                    }

                    if tour == nil {
                        OptionSection(label: "Help") {
                            Button {
                                replayOnboarding = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Show welcome tour")
                                        .appFont(Typography.body)
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.faint)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.haptic)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $replayOnboarding) {
            OnboardingView(settings: store.settings) { replayOnboarding = false }
        }
    }

    private var themePicker: some View {
        HStack(spacing: 3) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                let selected = store.settings.appTheme == theme
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.settings.appTheme = theme }
                } label: {
                    Text(theme.label)
                        .appFont(Typography.label)
                        .foregroundStyle(selected ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected ? Theme.accent.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.haptic)
            }
        }
        .padding(3)
    }

    private var fontSizePicker: some View {
        HStack(spacing: 3) {
            ForEach(FontSize.allCases, id: \.self) { size in
                let selected = store.settings.fontSize == size
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.settings.fontSize = size }
                } label: {
                    Text(size.label)
                        .appFont(Typography.label)
                        .foregroundStyle(selected ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selected ? Theme.accent.opacity(0.14) : .clear,
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

    private var streakReminderEnabled: Binding<Bool> {
        Binding(
            get: { store.settings.streakReminderEnabled },
            set: { enabled in
                guard enabled else {
                    store.settings.streakReminderEnabled = false
                    return
                }
                Task {
                    let granted = await ReminderScheduler.requestPermission()
                    store.settings.streakReminderEnabled = granted
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
                        .appFont(Typography.body)
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
                .appFont(Typography.body)
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
