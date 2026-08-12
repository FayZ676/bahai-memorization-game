import SwiftUI

enum LibraryRoute: Hashable {
    case achievements
}

extension EnvironmentValues {
    @Entry var popToLibrary: () -> Void = {}
}

private let deleteTitleWordLimit = 6

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()
    @State private var isTourPresented = false

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
        .onAppear {
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
            Button("Delete", role: .destructive) { store.deletePassage(passage) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
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

            Section {
                ForEach(Array(store.passagesSorted.enumerated()), id: \.element.id) { index, passage in
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
                    }
                }
            }
        }
        .listRowSpacing(Spacing.md)
        .listSectionSpacing(Spacing.md)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private var streakHeader: some View {
        StreakView(count: store.streakCount)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No passages yet.\nOpen the writings to get started.")
                .appFont(Typography.subtitle)
                .foregroundStyle(Theme.muted)
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
