import SwiftUI

extension EnvironmentValues {
    @Entry var popToLibrary: () -> Void = {}
    @Entry var openInLibrary: (Passage) -> Void = { _ in }
}

private let deleteTitleWordLimit = 6

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()
    @State private var isTourPresented = false
    @State private var releaseNote: ReleaseNote?
    @State private var showsArchived = false

    var body: some View {
        NavigationStack(path: $path) {
            Screen {
                ScreenHeader(title: "Library", leading: {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                    .accessibilityLabel("Settings")
                }, trailing: {
                    BrowseLink(.browse) {
                        Image(systemName: "book")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                    .accessibilityLabel("Writings")
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
            .navigationDestination(for: Passage.self) { passage in
                SessionView(passage: passage, store: store)
            }
            .browseDestinations()
        }
        .environment(\.popToLibrary) { path = NavigationPath() }
        .environment(\.openInLibrary, open)
        .guidedTour(
            isActive: isTourPresented,
            onRestart: { isTourPresented = true },
            onFinish: { isTourPresented = false }
        )
        .releaseNotes($releaseNote)
        .onOpenURL { url in
            guard let id = PracticeSnapshot.passageID(in: url), let passage = store.passage(withID: id) else { return }
            open(passage)
        }
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

    private func open(_ passage: Passage) {
        var opened = NavigationPath()
        opened.append(passage)
        path = opened
    }

    private func shortened(_ title: String) -> String {
        let words = title.split(separator: " ")
        guard words.count > deleteTitleWordLimit else { return title }
        return words.prefix(deleteTitleWordLimit).joined(separator: " ") + "…"
    }

    private var list: some View {
        List {
            Section {
                ForEach(store.activePassages) { passage in
                    row(for: passage)
                }
            }
            archived
        }
        .listRowSpacing(Spacing.sm)
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
                detail: Percent.label(store.hiddenFraction(for: passage))
            )
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
    private var archived: some View {
        let passages = store.archivedPassages
        if !passages.isEmpty {
            Section {
                archivedHeader(count: passages.count)

                if showsArchived {
                    ForEach(passages) { passage in
                        row(for: passage)
                    }
                }
            }
        }
    }

    private func archivedHeader(count: Int) -> some View {
        Button {
            Feedback.tap()
            withAnimation(.easeInOut(duration: 0.22)) { showsArchived.toggle() }
        } label: {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "archivebox")
                        .appIcon(13, weight: .regular)

                    Text("Archived")
                        .appFont(Typography.label.weight(.regular))
                }
                .foregroundStyle(Theme.faint)

                Text("\(count)")
                    .appFont(Typography.footnote)
                    .foregroundStyle(Theme.faint)

                Spacer()

                Image(systemName: "chevron.right")
                    .appIcon(12, weight: .regular)
                    .foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(showsArchived ? 90 : 0))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
