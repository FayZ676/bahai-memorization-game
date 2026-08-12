import SwiftUI

enum ContactPurpose {
    case reportIssue
    case feedback

    var title: String {
        switch self {
        case .reportIssue: return "Report Issue"
        case .feedback: return "Feedback"
        }
    }

    var messageLabel: String {
        switch self {
        case .reportIssue: return "Message (Optional)"
        case .feedback: return "Message"
        }
    }

    var prompt: String {
        switch self {
        case .reportIssue: return "What went wrong?"
        case .feedback: return "What would you like the app to do?"
        }
    }

    var sendTitle: String {
        switch self {
        case .reportIssue: return "Send Report"
        case .feedback: return "Send Feedback"
        }
    }

    var kind: String {
        switch self {
        case .reportIssue: return FeedbackForm.Kind.problem
        case .feedback: return FeedbackForm.Kind.feedback
        }
    }

    var offersSpeechHistory: Bool { self == .reportIssue }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared
    @State private var message = ""
    @State private var email = ""
    @State private var sendingSpeechHistory = true
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false
    @FocusState private var editorFocused: Bool
    let purpose: ContactPurpose

    private var attempts: [RecitationAttempt] {
        purpose.offersSpeechHistory && sendingSpeechHistory ? log.newestFirst : []
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !sending && (!trimmedMessage.isEmpty || !attempts.isEmpty)
    }

    var body: some View {
        Screen {
            ScreenHeader(title: purpose.title, onBack: { dismiss() })
        } content: {
            if sent {
                thanks
            } else {
                form
            }
        }
        .alert("Couldn't send", isPresented: $failed) {
            Button("Try again", action: send)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your message wasn't delivered. Check your connection and try again.")
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OptionSection(label: purpose.messageLabel, icon: "text.alignleft") {
                    editor
                }

                if purpose.offersSpeechHistory {
                    speechHistoryToggle
                }

                OptionSection(label: "Email (Optional)", icon: "envelope") {
                    EmailField(email: $email)
                }

                SendButton(title: purpose.sendTitle, sending: sending, enabled: canSend, action: send)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var speechHistoryToggle: some View {
        OptionSection(
            label: "Speech History",
            icon: "waveform",
            footer: hasSpeechHistory
                ? "Sends what the app heard during your recent recitations."
                : "Nothing recorded yet — recite a passage and your history will appear here."
        ) {
            Toggle(isOn: $sendingSpeechHistory) {
                Text("Include speech history")
                    .appFont(Typography.body)
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.accent)
            .disabled(!hasSpeechHistory)
            .optionRow()
        }
    }

    private var hasSpeechHistory: Bool { !log.attempts.isEmpty }

    private var thanks: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .appIcon(34, weight: .light)
                .foregroundStyle(Theme.accent)
            Text("Thank you")
                .appFont(Typography.heading)
                .foregroundStyle(Theme.ink)
            Text("Your note is on its way.")
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text(purpose.prompt)
                    .appFont(Typography.body)
                    .foregroundStyle(Theme.faint)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $message)
                .appFont(Typography.body)
                .foregroundStyle(Theme.ink)
                .tint(Theme.accent)
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: 120)
                .padding(.vertical, 12)
                .padding(.horizontal, 15)
        }
    }

    private func send() {
        editorFocused = false
        sending = true
        let note = trimmedMessage
        let address = email.trimmingCharacters(in: .whitespaces)
        let trace = RecitationLog.trace(of: attempts)
        Task {
            let delivered = await FeedbackForm.submit(
                kind: purpose.kind,
                message: note.isEmpty ? "Sent from the \(purpose.title) screen." : note,
                email: address,
                trace: trace
            )
            sending = false
            guard delivered else {
                failed = true
                return
            }
            Feedback.sessionComplete()
            withAnimation(.easeInOut(duration: 0.25)) { sent = true }
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }
}
