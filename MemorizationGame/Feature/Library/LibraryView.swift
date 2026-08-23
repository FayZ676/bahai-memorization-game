import SwiftUI

enum LibraryRoute: Hashable {
    case achievements
}

extension EnvironmentValues {
    @Entry var popToLibrary: () -> Void = {}
}

private let deleteTitleWordLimit = 6

private enum PassageGroup {
    case memorizing
    case archived

    var label: String {
        switch self {
        case .memorizing: "Memorizing"
        case .archived: "Archived"
        }
    }

    var symbol: String {
        switch self {
        case .memorizing: "text.word.spacing"
        case .archived: "archivebox"
        }
    }
}

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()
    @State private var isTourPresented = false
    @State private var releaseNote: ReleaseNote?
    @State private var expandedGroups: Set<PassageGroup> = [.memorizing]

    var body: some View {
        NavigationStack(path: $path) {
            Screen {
                ScreenHeader(title: "Library", slotWidth: 84, leading: {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                }, trailing: {
                    HStack(spacing: Spacing.sm) {
                        NavigationLink(value: LibraryRoute.achievements) {
                            Image(systemName: "trophy")
                                .foregroundStyle(hasAchievements ? Theme.gold : Theme.accent)
                        }
                        .buttonStyle(.icon)

                        BrowseLink(.browse) {
                            Image(systemName: "book")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.icon)
                    }
                })
            } content: {
                Group {
                    if store.passages.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .achievements:
                    AchievementsView()
                }
            }
            .navigationDestination(for: Passage.self) { passage in
                SessionView(passage: passage, store: store)
            }
            .browseDestinations()
        }
        .environment(\.popToLibrary) { path = NavigationPath() }
        .guidedTour(
            isActive: isTourPresented,
            onRestart: { isTourPresented = true },
            onFinish: { isTourPresented = false }
        )
        .releaseNotes($releaseNote)
        .onAppear {
            releaseNote = ReleaseNotes.unseen(version: AppInfo.version, settings: store.settings)
            store.markReleaseNotesSeen()
            guard !store.settings.hasSeenWelcomeTour else { return }
            store.settings.hasSeenWelcomeTour = true
            isTourPresented = true
        }
        .confirmationDialog(
            "Delete this passage?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { passage in
            Button("Delete", role: .destructive, action: Feedback.tapping {
                store.deletePassage(passage)
            })
            Button("Cancel", role: .cancel, action: Feedback.tapping { pendingDelete = nil })
        } message: { passage in
            Text("“\(shortened(passage.title))” and all its progress will be removed. This can't be undone.")
        }
    }

    private func shortened(_ title: String) -> String {
        let words = title.split(separator: " ")
        guard words.count > deleteTitleWordLimit else { return title }
        return words.prefix(deleteTitleWordLimit).joined(separator: " ") + "…"
    }

    private var hasAchievements: Bool { store.earnedAchievementCount > 0 }

    private var list: some View {
        List {
            Section {
                streakHeader
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            group(.memorizing, passages: store.activePassages)
            group(.archived, passages: store.archivedPassages)
        }
        .listRowSpacing(Spacing.md)
        .listSectionSpacing(Spacing.md)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private func row(for passage: Passage) -> some View {
        Button {
            Feedback.tap()
            path.append(passage)
        } label: {
            PassageCard(
                title: passage.title,
                author: passage.author,
                section: passage.section,
                detail: passage.dateAdded.elapsedDuration
            ) {
                ProgressBar(
                    heats: store.sectionHeats(for: passage),
                    weights: store.sectionWeights(for: passage),
                    completion: store.hiddenFraction(for: passage),
                    barHeight: 6
                )
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear.cardSurface())
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = passage
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                Feedback.tap()
                withAnimation(.easeInOut(duration: 0.22)) {
                    store.setArchived(passage, !passage.isArchived)
                }
            } label: {
                passage.isArchived
                    ? Label("Unarchive", systemImage: "tray.and.arrow.up")
                    : Label("Archive", systemImage: "archivebox")
            }
            .tint(Theme.faint)
        }
    }

    @ViewBuilder
    private func group(_ group: PassageGroup, passages: [Passage]) -> some View {
        if !passages.isEmpty {
            Section {
                groupHeader(group, count: passages.count)

                if expandedGroups.contains(group) {
                    ForEach(passages) { passage in
                        row(for: passage)
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: PassageGroup, count: Int) -> some View {
        Button {
            Feedback.tap()
            withAnimation(.easeInOut(duration: 0.22)) {
                if expandedGroups.contains(group) {
                    expandedGroups.remove(group)
                } else {
                    expandedGroups.insert(group)
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: group.symbol)
                        .appIcon(13, weight: .regular)

                    Text(group.label)
                        .appFont(Typography.label.weight(.regular))
                }
                .foregroundStyle(Theme.faint)

                Text("\(count)")
                    .appFont(Typography.footnote.mono())
                    .foregroundStyle(Theme.faint)

                Spacer()

                Image(systemName: "chevron.right")
                    .appIcon(12, weight: .regular)
                    .foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(expandedGroups.contains(group) ? 90 : 0))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var streakHeader: some View {
        VStack(spacing: Spacing.xl) {
            LibraryTally(streak: store.streakCount, memorized: store.memorizedPassageIDs.count)

            HairlineDivider()
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            BrowseLink(.browse) {
                Image(systemName: "book")
                    .appIcon(34)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(IconButtonStyle(size: 96))

            Text("Choose a prayer to get started")
                .appFont(Typography.body)
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension Date {
    var elapsedDuration: String {
        let now = Date()
        let units: [(Calendar.Component, String)] = [
            (.year, "y"), (.month, "mo"), (.weekOfYear, "w"), (.day, "d"), (.hour, "h"), (.minute, "m")
        ]
        let parts = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute],
            from: self, to: now
        )
        guard let leadIndex = units.firstIndex(where: { (parts.value(for: $0.0) ?? 0) > 0 }) else {
            return "now"
        }
        let lead = units[leadIndex]
        var text = "\(parts.value(for: lead.0) ?? 0)\(lead.1)"
        if leadIndex + 1 < units.count {
            let next = units[leadIndex + 1]
            if let value = parts.value(for: next.0), value > 0 {
                text += " \(value)\(next.1)"
            }
        }
        return text
    }
}
