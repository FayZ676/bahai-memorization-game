import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var email = ""
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false
    @FocusState private var editorFocused: Bool

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool { !trimmedMessage.isEmpty && !sending }

    var body: some View {
        Screen {
            ScreenHeader(title: "Feedback", onBack: { dismiss() })
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
            VStack(alignment: .leading, spacing: 22) {
                OptionSection(label: "Message", icon: "text.alignleft") {
                    editor
                }

                OptionSection(
                    label: "Email",
                    icon: "envelope",
                    footer: "Optional, and only used to reply. Your app version and device are sent along."
                ) {
                    TextField("So I can write back", text: $email)
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.ink)
                        .tint(Theme.accent)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                }

                SendButton(title: "Send Feedback", sending: sending, enabled: canSend, action: send)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

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
                Text("What would you like the app to do?")
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
                .frame(minHeight: 180)
                .padding(.vertical, 12)
                .padding(.horizontal, 15)
        }
    }

    private func send() {
        editorFocused = false
        sending = true
        let note = trimmedMessage
        let address = email.trimmingCharacters(in: .whitespaces)
        Task {
            let delivered = await FeedbackForm.submit(
                kind: FeedbackForm.Kind.feedback,
                message: note,
                email: address
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
