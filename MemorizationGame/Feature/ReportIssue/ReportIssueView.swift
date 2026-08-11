import SwiftUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var failed = false
    @FocusState private var editorFocused: Bool
    var chunkID: UUID?

    private var attempts: [RecitationAttempt] {
        chunkID.map { log.attempts(for: $0) } ?? log.newestFirst
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !sending && !sent && (!attempts.isEmpty || !trimmedMessage.isEmpty)
    }

    var body: some View {
        Screen {
            ScreenHeader(title: "Report Issue", onBack: { dismiss() })
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    record
                    OptionSection(label: "Message", icon: "text.alignleft") {
                        editor
                    }
                    sendRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Couldn't send", isPresented: $failed) {
            Button("Try again", action: send)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your report wasn't delivered. Check your connection and try again.")
        }
    }

    private var intro: some View {
        Text("Tell us what went wrong. Your recent recitations come along in case they're part of it.")
            .appFont(Typography.callout)
            .foregroundStyle(Theme.muted)
            .lineSpacing(3)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text("What went wrong?")
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
                .frame(minHeight: 84)
                .padding(.vertical, 12)
                .padding(.horizontal, 15)
        }
    }

    @ViewBuilder
    private var sendRow: some View {
        if sent {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .appIcon(16, weight: .semibold)
                    .foregroundStyle(Theme.accent)
                Text("Report sent — thank you")
                    .appFont(Typography.button)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .transition(.opacity)
        } else {
            Button(action: send) {
                Group {
                    if sending {
                        ProgressView().tint(Theme.bg)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .appIcon(15, weight: .semibold)
                            Text("Send Report")
                                .appFont(Typography.button)
                        }
                        .foregroundStyle(Theme.bg)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(canSend ? Theme.accent : Theme.accentMuted, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.haptic)
            .disabled(!canSend)
        }
    }

    @ViewBuilder
    private var record: some View {
        if attempts.isEmpty {
            InfoNote(Typography.micro, color: Theme.faint) {
                Text("No recitations recorded yet — just describe the issue below.")
                    .appFont(Typography.micro)
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 6)
        } else {
            OptionSection(label: "Recent recitations", icon: "waveform") {
                ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                    if index > 0 { HairlineDivider() }
                    AttemptRow(attempt: attempt, showsSource: chunkID == nil)
                }
            }
        }
    }

    private func send() {
        editorFocused = false
        sending = true
        let note = trimmedMessage
        let trace = RecitationLog.trace(of: attempts)
        Task {
            let delivered = await FeedbackForm.submit(
                kind: FeedbackKind.problem.rawValue,
                message: note.isEmpty ? "Reported from the Report Issue screen." : note,
                email: "",
                trace: trace
            )
            sending = false
            guard delivered else {
                failed = true
                return
            }
            Feedback.sessionComplete()
            withAnimation(.easeInOut(duration: 0.25)) { sent = true }
        }
    }
}

private struct AttemptRow: View {
    let attempt: RecitationAttempt
    let showsSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
            if attempt.misses.isEmpty {
                Text("Every word was heard")
                    .appFont(Typography.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                misses
                    .appFont(Typography.caption)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
    }

    private var header: String {
        let stamp = attempt.date.formatted(date: .abbreviated, time: .shortened)
        return showsSource
            ? "\(stamp) · \(attempt.passageTitle) · \(attempt.summary)"
            : "\(stamp) · \(attempt.summary)"
    }

    private var misses: Text {
        attempt.misses
            .map { miss in
                Text(miss.expected).foregroundStyle(Theme.ink)
                    + Text(" → ").foregroundStyle(Theme.faint)
                    + Text(miss.heardSomething ? miss.heard : "nothing")
                        .foregroundStyle(miss.heardSomething ? Theme.warn : Theme.muted)
            }
            .enumerated()
            .reduce(Text("")) { line, pair in
                pair.offset == 0 ? pair.element : line + Text("   ").foregroundStyle(Theme.faint) + pair.element
            }
    }
}
