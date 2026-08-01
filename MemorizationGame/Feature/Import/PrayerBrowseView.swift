import SwiftUI

struct PrayerBrowseView: View {
    var focusSection: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchResults: [Prayer] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Browse", onBack: { dismiss() })

            searchField

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if trimmedQuery.isEmpty {
                            pasteOwnRow
                            ForEach(PrayerLibrary.collections) { collection in
                                collectionCard(collection)
                            }
                        } else if isSearching {
                            loadingRow
                        } else if searchResults.isEmpty {
                            noResults
                        } else {
                            searchRows
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .task {
                    guard let focusSection else { return }
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(focusSection, anchor: .top)
                    }
                }
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .completesTourStep(.openBrowse)
        .onChange(of: query) { _, _ in
            let pending = trimmedQuery
            searchTask?.cancel()
            guard !pending.isEmpty else {
                searchResults = []
                isSearching = false
                return
            }
            isSearching = true
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                let results = await FuzzySearch.rank(query: pending)
                if Task.isCancelled || pending != trimmedQuery { return }
                searchResults = results
                isSearching = false
            }
        }
        .task {
            await Task.detached(priority: .userInitiated) {
                _ = PrayerLibrary.all
            }.value
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)
            TextField("Search prayers and writings", text: $query)
                .appFont(Typography.body)
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .appFont(Typography.body)
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.haptic)
            }
        }
        .padding(12)
        .cardSurface(cornerRadius: Radius.control)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(Theme.bg)
    }

    private func collectionCard(_ collection: PrayerLibrary.Collection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureNode(
                title: collection.name,
                font: Typography.passageTitle,
                color: Theme.ink,
                initiallyExpanded: true
            ) {
                ForEach(collection.sections) { section in
                    sectionNode(section)
                }
            }
        }
        .cardSurface(cornerRadius: Radius.group)
    }

    private func sectionNode(_ section: PrayerLibrary.Section) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.hairline)
            DisclosureNode(
                title: section.name,
                subtitle: "\(section.prayerCount)",
                font: Typography.caption,
                color: Theme.muted,
                tracking: 0.3,
                indent: 4,
                initiallyExpanded: section.name == focusSection
            ) {
                ForEach(Array(section.categories.enumerated()), id: \.element.id) { index, category in
                    NavigationLink(value: ImportRoute.category(category)) {
                        CategoryRow(category: category)
                    }
                    .buttonStyle(.haptic)

                    if index < section.categories.count - 1 {
                        Divider()
                            .overlay(Theme.hairline)
                            .padding(.leading, 32)
                            .padding(.trailing, 16)
                    }
                }
            }
        }
        .id(section.name)
    }

    private var pasteOwnRow: some View {
        NavigationLink(value: ImportRoute.pasteOwn) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Theme.accent)
                Text("Paste your own text")
                    .appFont(Typography.body)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface(cornerRadius: Radius.group)
        }
        .buttonStyle(.haptic)
    }

    private var searchRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, prayer in
                NavigationLink(value: ImportRoute.prayer(prayer)) {
                    PrayerRow(prayer: prayer, showSection: true)
                }
                .buttonStyle(.haptic)

                if index < searchResults.count - 1 {
                    Divider()
                        .overlay(Theme.hairline)
                        .padding(.horizontal, 16)
                }
            }
        }
        .cardSurface(cornerRadius: Radius.group)
    }

    private var loadingRow: some View {
        ProgressView()
            .tint(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private var noResults: some View {
        Text("No prayers match “\(trimmedQuery)”.")
            .appFont(Typography.body)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}

private struct CategoryRow: View {
    let category: PrayerLibrary.Category

    var body: some View {
        HStack(spacing: 10) {
            Text(category.name)
                .appFont(Typography.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text("\(category.prayers.count)")
                .appFont(Typography.footnote)
                .foregroundStyle(Theme.faint)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.leading, 32)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
