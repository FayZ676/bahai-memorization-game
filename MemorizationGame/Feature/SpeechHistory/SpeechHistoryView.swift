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
                footer: "What the app heard in place of each word you missed."
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
    @Environment(\.fontScale) private var scale
    @State private var overflow = OverflowEdges()
    let attempt: RecitationAttempt

    private static let fadeWidth: CGFloat = 26

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            (Text(header).font(Typography.micro.font(scale: scale)).foregroundStyle(Theme.faint)
                + Text("   ")
                + misses)
                .lineLimit(1)
                .padding(.horizontal, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onScrollGeometryChange(for: OverflowEdges.self) { geometry in
            OverflowEdges(
                offset: geometry.contentOffset.x,
                reach: geometry.contentSize.width - geometry.containerSize.width
            )
        } action: { _, edges in
            overflow = edges
        }
        .mask(fade)
        .animation(.easeOut(duration: 0.16), value: overflow)
        .padding(.vertical, Spacing.sm)
    }

    private var fade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflow.leading ? Self.fadeWidth : 0)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflow.trailing ? Self.fadeWidth : 0)
        }
    }

    private var header: String {
        let day = attempt.date.formatted(.dateTime.month(.abbreviated).day())
        let time = attempt.date.formatted(date: .omitted, time: .shortened)
        let stamp = "\(day), \(time)"
        return "\(stamp) · \(attempt.passageTitle) · \(attempt.summary)"
    }

    private var misses: Text {
        attempt.misses
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
                    : line + Text("  |  ").font(missFont).foregroundStyle(Theme.faint) + pair.element
            }
    }

    private var missFont: Font { Typography.caption.font(scale: scale) }
}

private struct OverflowEdges: Equatable {
    var offset: CGFloat = 0
    var reach: CGFloat = 0

    private static let slack: CGFloat = 1

    var leading: Bool { offset > Self.slack }
    var trailing: Bool { offset < reach - Self.slack }
}
