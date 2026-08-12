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

    var intro: String? {
        switch self {
        case .reportIssue: return "Tell us what went wrong."
        case .feedback: return nil
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

    var showsRecitations: Bool { self == .reportIssue }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared
    @State private var message = ""
    @State private var email = ""
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false
    @FocusState private var editorFocused: Bool
    let purpose: ContactPurpose

    private var attempts: [RecitationAttempt] {
        purpose.showsRecitations ? log.newestFirst : []
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
                if let intro = purpose.intro {
                    Text(intro)
                        .appFont(Typography.callout)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }

                OptionSection(label: "Message", icon: "text.alignleft") {
                    editor
                }

                if purpose.showsRecitations {
                    record
                }

                OptionSection(
                    label: "Email",
                    icon: "envelope",
                    footer: "Optional, and only used to reply. Your app version and device are sent along."
                ) {
                    EmailField(email: $email)
                }

                SendButton(title: purpose.sendTitle, sending: sending, enabled: canSend, action: send)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var record: some View {
        if !attempts.isEmpty {
            OptionSection(label: "Recent recitations", icon: "waveform") {
                ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                    if index > 0 { HairlineDivider() }
                    AttemptRow(attempt: attempt)
                }
            }
        }

        InfoNote(Typography.micro, color: Theme.faint) {
            Text(attempts.isEmpty
                ? "No recitations recorded yet."
                : "Recitation info is automatically included.")
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 6)
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

private struct AttemptRow: View {
    @Environment(\.fontScale) private var scale
    let attempt: RecitationAttempt

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            (Text(header).font(Typography.micro.font(scale: scale)).foregroundStyle(Theme.faint)
                + Text("   ")
                + misses)
                .lineLimit(1)
                .padding(.horizontal, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .padding(.vertical, Spacing.sm)
    }

    private var header: String {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        let stamp = "\(day), \(time)"
        return "\(stamp) · \(attempt.passageTitle) · \(attempt.summary)"
    }

    private var misses: Text {
        guard !attempt.misses.isEmpty else {
            return Text("Every word was heard").font(missFont).foregroundStyle(Theme.muted)
        }
        return attempt.misses
            .map { miss in
                Text(miss.expected).font(missFont).foregroundStyle(Theme.ink)
                    + Text(" → ").font(missFont).foregroundStyle(Theme.faint)
                    + Text(miss.heardSomething ? miss.heard : "nothing")
                        .font(missFont)
                        .foregroundStyle(miss.heardSomething ? Theme.warn : Theme.muted)
            }
            .enumerated()
            .reduce(Text("")) { line, pair in
                pair.offset == 0
                    ? pair.element
                    : line + Text("  |  ").font(missFont).foregroundStyle(Theme.hairline) + pair.element
            }
    }

    private var missFont: Font { Typography.caption.font(scale: scale) }
}
