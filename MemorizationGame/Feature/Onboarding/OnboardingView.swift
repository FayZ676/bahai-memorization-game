import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var joined = false

    private static let verse = ["Guide", "me,", "protect", "me,", "make", "of", "me", "a", "shining", "lamp"]
    private static let demoHiddenWords: Set<Int> = [2, 3, 8]
    private static let firstSection = ["Guide", "me,", "protect", "me,"]
    private static let secondSection = ["make", "of", "me", "a", "shining", "lamp"]

    private static let pages: [Page] = [
        Page(
            title: "Verses",
            body: "Commit prayers and sacred writings to memory, a few words at a time."
        ),
        Page(
            title: "Start with a prayer",
            body: "Tap plus to browse hundreds of prayers by category, or search for one by name. You can paste in your own writing just as easily."
        ),
        Page(
            title: "Hide a word, then recall it",
            body: "Tap any word to hide it, and tap again to bring it back. Read the line and fill the gaps from memory."
        ),
        Page(
            title: "Join what you know",
            body: "Once every word in a section is hidden, merge it with the one next to it. Recite longer and longer stretches until the whole prayer is a single passage."
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
            joined = false
            guard newValue == Self.pages.count - 1 else { return }
            withAnimation(Motion.standard.delay(0.7).repeatForever(autoreverses: true)) { joined = true }
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
            DemoCard { DemoWords(words: Self.verse, hidden: []) }
        case 1:
            DemoImport()
        case 2:
            DemoCard { DemoWords(words: Self.verse, hidden: Self.demoHiddenWords) }
        default:
            DemoMerge(first: Self.firstSection, second: Self.secondSection, joined: joined)
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

private struct DemoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xxl)
            .frame(maxWidth: .infinity)
            .cardSurface()
            .padding(.horizontal, Spacing.screen)
    }
}

private struct DemoWords: View {
    let words: [String]
    let hidden: Set<Int>

    var body: some View {
        FlowLayout(spacing: 7, lineSpacing: 12) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WordView(token: word, hidden: hidden.contains(index))
                    .appFont(Typography.recite)
            }
        }
    }
}

private struct DemoImport: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            row(title: "Long Healing Prayer", author: "Bahá’u’lláh")
            row(title: "Parents", author: "The Báb")
            row(title: "The Nineteen Day Feast", author: "‘Abdu’l‑Bahá")
        }
        .padding(.horizontal, Spacing.screen)
    }

    private func row(title: String, author: String) -> some View {
        PassageCard(title: title, author: author)
            .cardSurface(cornerRadius: Radius.group)
    }
}

private struct DemoMerge: View {
    let first: [String]
    let second: [String]
    let joined: Bool

    var body: some View {
        DemoCard {
            VStack(spacing: joined ? Spacing.xs : Spacing.lg) {
                DemoWords(words: first, hidden: Set(first.indices))

                ZStack {
                    HairlineDivider()
                    MergeChip(filled: true)
                }
                .opacity(joined ? 0 : 1)
                .frame(height: joined ? 0 : 24)

                DemoWords(words: second, hidden: Set(second.indices))
            }
        }
    }

}
