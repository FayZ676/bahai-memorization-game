import SwiftUI

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
            OptionSection(
                label: "Recent recitations",
                icon: "waveform",
                footer: "Tap a recitation to see every word you were owed — what the app heard on "
                    + "each try, and how the word ended up.",
                content: {
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
                },
                accessory: { filterMenu }
            )
            .padding(.horizontal, 18)
            .padding(.bottom, Spacing.screen)
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(RecitationFilter.allCases) { filter in
                Button {
                    Feedback.tap()
                    withAnimation(Motion.toggle) { toggle(filter) }
                } label: {
                    Label(filter.label, systemImage: filters.contains(filter) ? "checkmark" : filter.icon)
                }
            }
            if !filters.isEmpty {
                Divider()
                Button {
                    Feedback.tap()
                    withAnimation(Motion.toggle) { filters = [] }
                } label: {
                    Label("Show All", systemImage: "line.3.horizontal.decrease")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filters.isEmpty
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill")
                    .appIcon(13, weight: .semibold)
                if !filters.isEmpty {
                    Text(filterLabel)
                        .appFont(Typography.footnote)
                        .tracking(0.3)
                }
            }
            .foregroundStyle(filters.isEmpty ? Theme.faint : Theme.ink)
            .contentShape(Rectangle())
        }
    }

    private var filterLabel: String {
        RecitationFilter.allCases
            .filter { filters.contains($0) }
            .map(\.label)
            .joined(separator: " · ")
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
            Text(header)
                .appFont(Typography.micro)
                .foregroundStyle(Theme.faint)
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

    private var header: String {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        let stamp = "\(day), \(time)"
        return "\(stamp) · \(attempt.passageTitle) · \(attempt.summary)"
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
            if review.tries.isEmpty, let miss = review.miss {
                line(
                    lead: "heard",
                    heard: miss.heard,
                    tint: miss.heardSomething ? Theme.warn : Theme.muted
                )
            }
        }
    }

    private var headline: some View {
        (Text(review.expected).foregroundStyle(Theme.ink)
            + Text(" · ").foregroundStyle(Theme.faint)
            + Text(detail).foregroundStyle(Theme.faint))
            .appFont(Typography.caption)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(lead: String, heard: String, tint: Color) -> some View {
        (Text("\(lead)  ").foregroundStyle(Theme.faint)
            + Text(heard.isEmpty ? "nothing" : "“\(heard)”")
                .foregroundStyle(heard.isEmpty ? Theme.muted : tint))
            .appFont(Typography.micro)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
    }

    private var detail: String {
        let count = review.tries.count
        guard count > 0 else { return review.verdict }
        return "\(review.verdict) after \(count) tr\(count == 1 ? "y" : "ies")"
    }
}
