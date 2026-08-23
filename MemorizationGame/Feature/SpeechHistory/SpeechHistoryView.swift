import SwiftUI

private let capHeightRatio: CGFloat = 0.72

private func inlineSymbol(
    _ name: String,
    tint: Color,
    alongside token: AppTextToken,
    scale: CGFloat
) -> Text {
    let text = token.size * scale
    let glyph = text * 0.66
    return Text(Image(systemName: name))
        .font(.system(size: glyph, weight: .regular))
        .baselineOffset((text - glyph) * capHeightRatio / 2)
        .foregroundStyle(tint)
}

extension RecitationFilter {
    var tint: Color {
        switch self {
        case .misses: Theme.missed
        case .skipped: Theme.skipped
        case .retries: Theme.retried
        }
    }

    func symbol(alongside token: AppTextToken, scale: CGFloat) -> Text {
        inlineSymbol(icon, tint: tint, alongside: token, scale: scale)
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
            .overlay(Capsule().strokeBorder(on ? filter.tint : Theme.hairline, lineWidth: on ? 1.5 : 1))
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
    @Environment(\.fontScale) private var fontScale
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
                .accessibilityLabel(spokenHeader)
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
        var line = Text(timestamp)
            .font(Typography.micro.mono().font(scale: fontScale))
            .foregroundStyle(Theme.faint)
            + Text(" · \(attempt.passageTitle)").foregroundStyle(Theme.faint)
        for (filter, count) in tallies {
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text("\(count) ")
                    .font(Typography.micro.mono().font(scale: fontScale))
                    .foregroundStyle(filter.tint)
                + filter.symbol(alongside: Typography.micro, scale: fontScale)
        }
        return line
    }

    private var spokenHeader: String {
        let counts = tallies.map { "\($0.count) \($0.filter.label.lowercased())" }
        return ([occasion] + counts).joined(separator: ", ")
    }

    private var timestamp: String {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        return "\(day), \(time)"
    }

    private var occasion: String {
        "\(timestamp) · \(attempt.passageTitle)"
    }

    private var tallies: [(filter: RecitationFilter, count: Int)] {
        let reviews = attempt.wordReviews
        return RecitationFilter.allCases.compactMap { filter in
            let count = reviews.filter(filter.admits).count
            return count > 0 ? (filter, count) : nil
        }
    }
}

struct WordReviewBlock: View {
    @Environment(\.fontScale) private var fontScale
    let review: RecitationWordReview

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headline
            ForEach(Array(review.tries.enumerated()), id: \.element.id) { index, entry in
                line(try: index, heard: entry.heard, landed: entry.accepted)
            }
            if review.tries.isEmpty, let miss = review.miss, miss.heardSomething {
                line(try: 0, heard: miss.heard, landed: false)
            }
        }
    }

    private var headline: some View {
        let named = RecitationFilter.allCases.filter { $0 != .retries && $0.admits(review) }
        var line = Text(review.expected).foregroundStyle(Theme.ink)
        for filter in named {
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text(filter.label.lowercased()).foregroundStyle(filter.tint)
        }
        let count = review.tries.count
        if count > 1 || (named.isEmpty && count > 0) {
            line = line
                + Text(" · ").foregroundStyle(Theme.faint)
                + Text("\(count)")
                    .font(Typography.caption.mono().font(scale: fontScale))
                    .foregroundStyle(review.isRetried ? Theme.retried : Theme.faint)
                + Text(" tr\(count == 1 ? "y" : "ies")")
                    .foregroundStyle(review.isRetried ? Theme.retried : Theme.faint)
        }
        return line
            .appFont(Typography.caption)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(try index: Int, heard: String, landed: Bool) -> some View {
        (Text("try ").foregroundStyle(Theme.faint)
            + Text("\(index + 1) ")
                .font(Typography.micro.mono().font(scale: fontScale))
                .foregroundStyle(Theme.faint)
            + inlineSymbol(
                landed ? "checkmark" : "xmark",
                tint: landed ? Theme.landed : Theme.missed,
                alongside: Typography.micro,
                scale: fontScale
            )
            + Text("  ").foregroundStyle(Theme.faint)
            + Text("“\(heard)”").foregroundStyle(Theme.ink).italic())
            .appFont(Typography.micro)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
    }

}
