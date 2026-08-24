import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tour) private var tour
    @Environment(\.restartWelcomeTour) private var restartWelcomeTour
    @Environment(\.showReleaseNotes) private var showReleaseNotes
    @Environment(\.openURL) private var openURL
    @State private var permissionDenied = false

    var body: some View {
        Screen {
            ScreenHeader(title: "Settings", onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OptionSection(label: "Appearance", icon: "circle.lefthalf.filled") {
                        SegmentedPicker(
                            options: AppTheme.allCases,
                            label: \.label,
                            selected: store.settings.appTheme
                        ) { store.settings.appTheme = $0 }
                    }

                    OptionSection(label: "Text Size", icon: "textformat.size") {
                        SegmentedPicker(
                            options: FontSize.allCases,
                            label: \.label,
                            selected: store.settings.fontSize
                        ) { store.settings.fontSize = $0 }
                    }

                    RemindersSection(permissionDenied: $permissionDenied)

                    OptionSection(label: "Help", icon: "questionmark.circle") {
                        Button {
                            restartWelcomeTour()
                            dismiss()
                        } label: {
                            DisclosureRow(tour == nil ? "Show welcome tour" : "Restart welcome tour")
                        }
                        .buttonStyle(.haptic)

                        HairlineDivider()

                        Button {
                            showReleaseNotes()
                            dismiss()
                        } label: {
                            DisclosureRow("What's new")
                        }
                        .buttonStyle(.haptic)
                    }

                    OptionSection(label: "Feedback", icon: "envelope") {
                        NavigationLink {
                            SpeechHistoryView()
                        } label: {
                            DisclosureRow("Speech History")
                        }
                        .buttonStyle(.haptic)

                        HairlineDivider()

                        NavigationLink {
                            ContactView(purpose: .reportIssue)
                        } label: {
                            DisclosureRow("Report Issue")
                        }
                        .buttonStyle(.haptic)

                        HairlineDivider()

                        NavigationLink {
                            ContactView(purpose: .feedback)
                        } label: {
                            DisclosureRow("Send feedback")
                        }
                        .buttonStyle(.haptic)
                    }

                    footer
                }
                .padding(.horizontal, 18)
                .padding(.bottom, Spacing.screen)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Text(AppInfo.releaseSummary)
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)

            Button {
                openURL(AppInfo.privacyPolicy)
            } label: {
                Text("Privacy Policy")
                    .appFont(Typography.micro)
                    .foregroundStyle(Theme.muted)
                    .underline()
                    .padding(.vertical, Spacing.xxs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.haptic)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
