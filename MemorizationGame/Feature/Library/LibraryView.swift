import SwiftUI

enum LibraryRoute: Hashable {
    case achievements
}

enum ImportRoute: Hashable {
    case browse
    case category(PrayerLibrary.Category)
    case prayer(Prayer)
    case pasteOwn
    case importPrayer(Prayer)
}

extension EnvironmentValues {
    @Entry var popToLibrary: () -> Void = {}
}

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()

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
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(hasAchievements ? Theme.gold : Theme.accent)
                        }
                        .buttonStyle(.icon)

                        NavigationLink(value: ImportRoute.browse) {
                            Image(systemName: "plus")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.icon)
                        .tourAnchor(.addPassage)
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
            .navigationDestination(for: ImportRoute.self) { route in
                switch route {
                case .browse:
                    PrayerBrowseView()
                case .category(let category):
                    PrayerCategoryView(category: category)
                case .prayer(let prayer):
                    PrayerDetailView(prayer: prayer)
                case .pasteOwn:
                    ImportView()
                case .importPrayer(let prayer):
                    ImportView(
                        initialTitle: prayer.title,
                        initialContent: prayer.text,
                        author: prayer.author,
                        section: prayer.section,
                        sourceID: prayer.id
                    )
                }
            }
        }
        .environment(\.popToLibrary) { path = NavigationPath() }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView(settings: store.settings) { store.settings.hasCompletedOnboarding = true }
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
            Text("“\(passage.title)” and all its progress will be removed. This can't be undone.")
        }
    }

    private var hasAchievements: Bool { store.earnedAchievementCount > 0 }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !store.settings.hasCompletedOnboarding },
            set: { presented in
                if !presented { store.settings.hasCompletedOnboarding = true }
            }
        )
    }

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
                            HeatStrip(
                                heats: store.sectionHeats(for: passage),
                                weights: store.sectionWeights(for: passage)
                            )
                            .frame(height: 6)
                        }
                    }
                    .buttonStyle(.plain)
                    .tourAnchor(index == 0 ? .passageRow : nil)
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
            Text("No passages yet.\nBrowse prayers to get started.")
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
        for (component, suffix) in units {
            if let value = parts.value(for: component), value > 0 {
                return "\(value)\(suffix)"
            }
        }
        return "now"
    }
}
