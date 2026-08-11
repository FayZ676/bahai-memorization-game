import SwiftUI

struct SpeechLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared
    var chunkID: UUID?

    private var attempts: [RecitationAttempt] {
        chunkID.map { log.attempts(for: $0) } ?? log.newestFirst
    }

    private var showsSource: Bool { chunkID == nil }

    var body: some View {
        Screen {
            ScreenHeader(title: "Speech Logs", onBack: { dismiss() }) {
                if !attempts.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if let chunkID {
                                log.clear(chunkID: chunkID)
                            } else {
                                log.clearAll()
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.navIcon)
                    }
                    .buttonStyle(.icon)
                }
            }
        } content: {
            if attempts.isEmpty {
                empty
            } else {
                list
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .appIcon(30, weight: .light)
                .foregroundStyle(Theme.faint)
            Text("Nothing recorded yet")
                .appFont(Typography.subtitle)
                .foregroundStyle(Theme.ink)
            Text("Recite from memory, and any word counted as missed is listed here with what the app heard instead.")
                .appFont(Typography.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(attempts) { attempt in
                    OptionSection(label: Self.stamp(attempt.date), icon: "clock") {
                        if showsSource {
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
                InfoNote(Typography.micro, color: Theme.faint) {
                    Text("These are the words the app counted as missed. If one was right, it was misheard — send feedback and the log comes with it.")
                        .appFont(Typography.micro)
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
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
