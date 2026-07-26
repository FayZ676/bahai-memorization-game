import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var decayed = false

    private static let verse = ["Guide", "me,", "protect", "me,", "make", "of", "me", "a", "shining", "lamp"]
    private static let demoHiddenWords: Set<Int> = [2, 3, 8]

    private static let pages: [Page] = [
        Page(
            title: "Verses",
            body: "Commit prayers and sacred writings to memory, a few words at a time."
        ),
        Page(
            title: "Hide a word, then recall it",
            body: "Tap any word in a passage to hide it. Read the line and fill the gaps from memory."
        ),
        Page(
            title: "Memory fades, and so do the words",
            body: "Hidden words quietly return if you stay away. Practice often and they stay hidden, so a passage always shows you where memory is thinning."
        )
    ]

    private struct Page {
        let title: String
        let body: String
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $page) {
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, content in
                    pageBody(index: index, content: content)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.bottom, Spacing.xl)

            primaryButton
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.screen)
        }
        .background(Theme.bg)
        .onChange(of: page) { _, newValue in
            Feedback.navigate(forward: true)
            guard newValue == 2 else {
                decayed = false
                return
            }
            decayed = false
            withAnimation(Motion.fade.delay(0.4).repeatForever(autoreverses: true)) { decayed = true }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: finish) {
                Text(page == Self.pages.count - 1 ? "Close" : "Skip")
                    .appFont(Typography.label)
                    .tracking(0.5)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.haptic)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func pageBody(index: Int, content: Page) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: 0)

            illustration(for: index)

            VStack(spacing: Spacing.md) {
                Text(content.title)
                    .appFont(Typography.heading)
                    .foregroundStyle(Theme.inkBright)
                    .multilineTextAlignment(.center)

                Text(content.body)
                    .appFont(Typography.body)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Spacing.screen)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        switch index {
        case 0:
            DemoVerse(words: Self.verse, hidden: [], decayReveal: 0)
        case 1:
            DemoVerse(words: Self.verse, hidden: Self.demoHiddenWords, decayReveal: 0)
        default:
            DemoVerse(words: Self.verse, hidden: Self.demoHiddenWords, decayReveal: decayed ? 1 : 0)
        }
    }

    private var dots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<Self.pages.count, id: \.self) { index in
                Circle()
                    .fill(index == page ? Theme.accent : Theme.accentMuted)
                    .frame(width: 7, height: 7)
            }
        }
        .animation(Motion.micro, value: page)
    }

    private var primaryButton: some View {
        Button(action: advance) {
            Text(page == Self.pages.count - 1 ? "Begin" : "Continue")
                .appFont(Typography.button)
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(Theme.accent, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.haptic)
    }

    private func advance() {
        guard page < Self.pages.count - 1 else {
            Feedback.sessionComplete()
            onFinish()
            return
        }
        withAnimation(Motion.standard) { page += 1 }
    }

    private func finish() {
        onFinish()
    }
}

private struct DemoVerse: View {
    let words: [String]
    let hidden: Set<Int>
    let decayReveal: Double

    var body: some View {
        FlowLayout(spacing: 7, lineSpacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let isHidden = hidden.contains(index)
                Text(word)
                    .appFont(Typography.recite)
                    .foregroundStyle(Theme.ink)
                    .opacity(isHidden ? decayReveal : 1)
                    .blur(radius: isHidden ? 2 * (1 - decayReveal) : 0)
                    .overlay(alignment: .bottom) {
                        if isHidden {
                            RoundedRectangle(cornerRadius: Radius.line, style: .continuous)
                                .fill(Theme.muted)
                                .frame(height: 2)
                                .offset(y: 3)
                        }
                    }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xxl)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .padding(.horizontal, Spacing.screen)
    }
}
