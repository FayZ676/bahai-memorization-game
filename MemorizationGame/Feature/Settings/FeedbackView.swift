import SwiftUI

enum FeedbackKind: String, CaseIterable {
    case problem = "Problem"
    case idea = "Idea"
    case other = "Other"

    var label: String { rawValue }

    var prompt: String {
        switch self {
        case .problem: return "What went wrong, and what were you doing when it happened?"
        case .idea: return "What would you like the app to do?"
        case .other: return "Anything you'd like to say."
        }
    }
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: FeedbackKind = .problem
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
            ScreenHeader(title: "Feedback", onBack: { dismiss() }) {
                Button(action: send) {
                    if sending {
                        ProgressView().tint(Theme.muted)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(canSend ? Theme.accent : Theme.disabled)
                    }
                }
                .buttonStyle(.icon)
                .disabled(!canSend)
            }
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
                OptionSection(label: "Kind", icon: "tag") {
                    kindPicker
                }

                OptionSection(label: "Message", icon: "text.alignleft") {
                    editor
                }

                OptionSection(
                    label: "Email",
                    icon: "envelope",
                    footer: "Optional, and only used to reply. Your app version and device are sent along so problems are easier to trace."
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
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
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

    private var kindPicker: some View {
        HStack(spacing: 3) {
            ForEach(FeedbackKind.allCases, id: \.self) { option in
                let selected = kind == option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { kind = option }
                } label: {
                    Text(option.label)
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

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text(kind.prompt)
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
        let payload = (kind: kind.rawValue, message: trimmedMessage, email: email.trimmingCharacters(in: .whitespaces))
        Task {
            let delivered = await FeedbackForm.submit(
                kind: payload.kind,
                message: payload.message,
                email: payload.email
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
