import SwiftUI

struct SpeechHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared

    var body: some View {
        Screen {
            ScreenHeader(title: "Speech History", onBack: { dismiss() })
        } content: {
            if log.attempts.isEmpty {
                empty
            } else {
                attempts
            }
        }
    }

    private var attempts: some View {
        ScrollView {
            OptionSection(
                label: "Recent recitations",
                icon: "waveform",
                footer: "Tap a recitation to see what the app heard in place of each word you missed."
            ) {
                ForEach(Array(log.newestFirst.enumerated()), id: \.element.id) { index, attempt in
                    if index > 0 { HairlineDivider() }
                    AttemptRow(attempt: attempt)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, Spacing.screen)
        }
    }

    private var empty: some View {
        Text("No recitations recorded yet.")
            .appFont(Typography.subtitle)
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
    }
}

struct AttemptRow: View {
    @State private var expanded = false
    let attempt: RecitationAttempt

    var body: some View {
        Button {
            withAnimation(Motion.toggle) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                summary
                if expanded { misses }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .optionRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
        .disabled(attempt.misses.isEmpty)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(header)
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if !attempt.misses.isEmpty {
                Image(systemName: "chevron.down")
                    .appIcon(11, weight: .semibold)
                    .foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
    }

    private var misses: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attempt.misses) { miss in
                (Text(miss.expected).foregroundStyle(Theme.ink)
                    + Text("  →  ").foregroundStyle(Theme.faint)
                    + Text(miss.heardSomething ? miss.heard : "nothing")
                        .foregroundStyle(miss.heardSomething ? Theme.warn : Theme.muted))
                    .appFont(Typography.caption)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: String {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        let stamp = "\(day), \(time)"
        return "\(stamp) · \(attempt.passageTitle) · \(attempt.summary)"
    }
}
