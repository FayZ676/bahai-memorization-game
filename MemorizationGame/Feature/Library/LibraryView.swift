import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScreenHeader(title: "Library", leading: {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                }, trailing: {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.icon)
                })

                Group {
                    if store.passages.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Passage.self) { passage in
                SessionView(passage: passage, store: store)
            }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionView(passage: route.passage, store: store, focusCardID: route.focusCardID)
            }
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

    private var list: some View {
        List {
            Section {
                streakHeader
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                StreakCard(practice: { path.append($0) })
                    .listRowBackground(streakBackground)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(store.passagesSorted) { passage in
                    Button {
                        Feedback.tap()
                        path.append(passage)
                    } label: {
                        PassageRow(passage: passage)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
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
            } header: {
                sectionHeader("Passages")
            }
        }
        .listRowSpacing(12)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private var streakHeader: some View {
        let today = Date()
        return HStack(alignment: .bottom, spacing: 12) {
            BurningNumberView(
                value: store.streakCount,
                today: FlameDay(
                    words: store.practiceLog.words(on: today),
                    heat: store.practiceLog.heat(on: today)
                ),
                fontSize: 44
            )
            Text("Day Streak")
                .font(Typography.footnote)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.faint)
                .padding(.bottom, 14)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.footnote)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Theme.faint)
    }

    private var streakBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        return shape
            .fill(Theme.rowBg)
            .overlay {
                if store.practicedToday {
                    shape.fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.10), .clear],
                            center: UnitPoint(x: 0.18, y: 0),
                            startRadius: 0,
                            endRadius: 240
                        )
                    )
                }
            }
            .overlay(
                shape.stroke(
                    store.practicedToday ? Theme.accent.opacity(0.3) : Theme.hairline,
                    lineWidth: 1
                )
            )
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No passages yet.\nImport one to get started.")
                .font(Typography.subtitle)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PassageRow: View {
    @Environment(AppStore.self) private var store
    let passage: Passage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(passage.title)
                    .font(Typography.title)
                    .foregroundStyle(Theme.ink)

                Text("Added \(passage.dateAdded.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(Typography.footnote)
                    .foregroundStyle(Theme.faint)
            }

            HeatStrip(heats: store.chunkHeats(for: passage))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
    }
}
