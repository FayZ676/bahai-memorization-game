import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: Passage?

    var body: some View {
        NavigationStack {
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
                SessionView(passage: passage)
            }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionView(passage: route.passage, focusCardID: route.focusCardID)
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
                StreakCard()
                    .listRowBackground(streakBackground)
                    .listRowSeparator(.hidden)
            } header: {
                sectionHeader("Practice Streak")
            }

            Section {
                ForEach(store.passagesSorted) { passage in
                    PassageRow(passage: passage)
                        .overlay {
                            NavigationLink(value: passage) { EmptyView() }
                                .opacity(0)
                        }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.rowBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.hairline, lineWidth: 1)
                            )
                    )
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
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
                .font(.body)
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
                    .font(.scripture(19, weight: .medium))
                    .foregroundStyle(Theme.ink)

                Text("Added \(passage.dateAdded.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.faint)
            }

            HeatStrip(heats: store.chunkHeats(for: passage))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
    }
}
