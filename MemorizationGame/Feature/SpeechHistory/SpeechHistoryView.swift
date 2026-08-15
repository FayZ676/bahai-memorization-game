import SwiftUI

extension RecitationFilter {
    var tint: Color {
        switch self {
        case .misses: Theme.missed
        case .skipped: Theme.skipped
        case .retries: Theme.retried
        }
    }
}

struct SpeechHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var log = RecitationLog.shared
    @State private var filters: Set<RecitationFilter> = []

    var body: some View {
        Screen {
            ScreenHeader(title: "Speech History", onBack: { dismiss() })
        } content: {
            if log.attempts.isEmpty {
                empty("No recitations recorded yet.")
            } else {
                attempts
            }
        }
    }

    private var visible: [RecitationAttempt] {
        log.newestFirst.filter { !$0.wordReviews(matching: filters).isEmpty }
    }

    private var attempts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                chips
                OptionSection(
                    label: "Recent recitations",
                    icon: "waveform",
                    footer: "Tap a recitation to see every word you were owed — what the app heard "
                        + "on each try, and how the word ended up."
                ) {
                    if visible.isEmpty {
                        Text("Nothing matches this filter.")
                            .appFont(Typography.caption)
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .optionRow()
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, attempt in
                            if index > 0 { HairlineDivider() }
                            AttemptRow(attempt: attempt, filters: filters)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, Spacing.screen)
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Filter", icon: "line.3.horizontal.decrease")
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.sm) {
                    ForEach(RecitationFilter.allCases) { filter in
                        chip(filter)
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func chip(_ filter: RecitationFilter) -> some View {
        let on = filters.contains(filter)
        return Button {
            toggle(filter)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .appIcon(13, weight: .semibold)
                Text(filter.label)
                    .appFont(Typography.label)
                    .lineLimit(1)
            }
            .foregroundStyle(filter.tint)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 9)
            .background(on ? filter.tint.opacity(0.18) : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? filter.tint : Theme.hairline, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.haptic)
    }

    private func toggle(_ filter: RecitationFilter) {
        if filters.contains(filter) {
            filters.remove(filter)
        } else {
            filters.insert(filter)
        }
    }

    private func empty(_ message: String) -> some View {
        Text(message)
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
    var filters: Set<RecitationFilter> = []

    private var shown: [RecitationWordReview] { attempt.wordReviews(matching: filters) }

    var body: some View {
        Button {
            withAnimation(Motion.toggle) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                summary
                if expanded { reviews }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .optionRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.haptic)
        .disabled(!attempt.hasDetail)
        .onAppear { expanded = !filters.isEmpty }
        .onChange(of: filters) { _, active in
            withAnimation(Motion.toggle) { expanded = !active.isEmpty }
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            header
                .appFont(Typography.micro)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if attempt.hasDetail {
                Image(systemName: "chevron.down")
                    .appIcon(11, weight: .semibold)
                    .foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(shown) { review in
                WordReviewBlock(review: review)
            }
        }
    }

    private var header: Text {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        var line = Text("\(day), \(time) · \(attempt.passageTitle)")
            .foregroundStyle(Theme.faint)
        let reviews = attempt.wordReviews
        for filter in RecitationFilter.allCases {
            let count = reviews.filter(filter.admits).count
            guard count > 0 else { continue }
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text("\(count) \(filter.label.lowercased())").foregroundStyle(filter.tint)
        }
        return line
    }
}

struct WordReviewBlock: View {
    let review: RecitationWordReview

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headline
            ForEach(review.tries) { entry in
                line(
                    lead: entry.accepted ? "took" : "heard",
                    heard: entry.heard,
                    tint: entry.accepted ? Theme.ink : Theme.warn
                )
            }
            if review.tries.isEmpty, let miss = review.miss, miss.heardSomething {
                line(lead: "heard", heard: miss.heard, tint: Theme.warn)
            }
        }
    }

    private var headline: some View {
        var line = Text(review.expected).foregroundStyle(Theme.ink)
        for filter in RecitationFilter.allCases
        where filter != .retries && filter.admits(review) {
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text(filter.label).foregroundStyle(filter.tint)
        }
        let count = review.tries.count
        if count > 0 {
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text("\(count) tr\(count == 1 ? "y" : "ies")")
                    .foregroundStyle(review.isRetried ? Theme.retried : Theme.faint)
        }
        return line
            .appFont(Typography.caption)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(lead: String, heard: String, tint: Color) -> some View {
        (Text("\(lead)  ").foregroundStyle(Theme.faint)
            + Text("“\(heard)”").foregroundStyle(tint).italic())
            .appFont(Typography.micro)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
    }

}
