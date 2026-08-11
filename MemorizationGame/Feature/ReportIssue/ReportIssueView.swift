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
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    OptionSection(
                        label: "Message",
                        icon: "text.alignleft",
                        footer: "Optional. The record below is sent either way."
                    ) {
                        editor
                    }
                    sendRow
                    record
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
        VStack(alignment: .leading, spacing: 8) {
            Text("When a word you said is counted as missed")
                .appFont(Typography.subtitle)
                .foregroundStyle(Theme.ink)
            Text("The app matches what it hears against the words you've hidden, and sometimes it gets one wrong. Below is what it heard the last few times you recited. Sending it shows exactly where the matching went astray — nothing else about you is included.")
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text("Anything you'd like to add?")
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
                .frame(minHeight: 110)
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
                        Text("Send Report")
                            .appFont(Typography.button)
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
                Text("Nothing recorded yet. Recite from memory and whatever the app mishears will show up here.")
                    .appFont(Typography.micro)
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 6)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(attempts) { attempt in
                    OptionSection(label: Self.stamp(attempt.date), icon: "clock") {
                        if chunkID == nil {
                            SourceRow(attempt: attempt)
                            HairlineDivider()
                        }
                        if attempt.misses.isEmpty {
                            Text("Every word was heard.")
                                .appFont(Typography.body)
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .optionRow()
                        } else {
                            ForEach(Array(attempt.misses.enumerated()), id: \.element.id) { index, miss in
                                if index > 0 { HairlineDivider() }
                                MissRow(miss: miss)
                            }
                        }
                    }
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

    private static func stamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct SourceRow: View {
    let attempt: RecitationAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(attempt.passageTitle)
                .appFont(Typography.label)
                .foregroundStyle(Theme.ink)
            Text("\(attempt.excerpt)… · \(attempt.summary)")
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .optionRow()
    }
}

private struct MissRow: View {
    let miss: RecitationMiss

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(miss.expected)
                .appFont(Typography.verse)
                .foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("heard")
                    .appFont(Typography.micro)
                    .tracking(0.5)
                    .foregroundStyle(Theme.faint)
                Text(miss.heardSomething ? "“\(miss.heard)”" : "nothing")
                    .appFont(Typography.callout)
                    .foregroundStyle(miss.heardSomething ? Theme.warn : Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .optionRow()
    }
}
