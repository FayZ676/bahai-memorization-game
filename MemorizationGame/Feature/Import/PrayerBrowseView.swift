import SwiftUI

struct PrayerBrowseView: View {
    var focusSection: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.tour) private var tour
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var searchResults: [SearchHit] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isChoosingTourPassage: Bool {
        guard let tour else { return false }
        return tour.step.rawValue <= TourStep.pickPrayer.rawValue
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Writings", onBack: { dismiss() })

            searchField

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if trimmedQuery.isEmpty {
                            pasteOwnRow
                            if hasMyWritings {
                                myWritingsCard
                            }
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
                try? await Task.sleep(for: .milliseconds(120))
                if Task.isCancelled { return }
                let results = await FuzzySearch.rank(query: pending)
                if Task.isCancelled || pending != trimmedQuery { return }
                searchResults = results
                isSearching = false
            }
        }
        .task {
            await Task.detached(priority: .userInitiated) {
                FuzzySearch.prewarm()
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

    private var hasMyWritings: Bool {
        !store.savedWritings.isEmpty || !store.recentlyReadPrayers.isEmpty
    }

    private var myWritingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureNode(
                title: "My Writings",
                font: Typography.passageTitle,
                color: Theme.ink,
                initiallyExpanded: !isChoosingTourPassage
            ) {
                if !store.savedWritings.isEmpty {
                    writingsRow(
                        title: "Saved",
                        count: store.savedWritings.count,
                        route: .savedWritings
                    )
                }
                if !store.recentlyReadPrayers.isEmpty {
                    writingsRow(
                        title: "Recently read",
                        count: store.recentlyReadPrayers.count,
                        route: .recentlyRead
                    )
                }
            }
        }
        .cardSurface(cornerRadius: Radius.group)
    }

    private func writingsRow(title: String, count: Int, route: BrowseRoute) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.hairline)
            BrowseLink(route) {
                SectionLinkRow(title: title, count: count)
            }
            .buttonStyle(.haptic)
        }
    }

    private func collectionCard(_ collection: PrayerLibrary.Collection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureNode(
                title: collection.name,
                font: Typography.passageTitle,
                color: Theme.ink,
                initiallyExpanded: !isChoosingTourPassage
                    || collection.name == PrayerLibrary.hiddenWordsCollection
            ) {
                ForEach(collection.sections) { section in
                    sectionNode(section)
                }
            }
        }
        .cardSurface(cornerRadius: Radius.group)
        .id(collection.name)
    }

    @ViewBuilder
    private func sectionNode(_ section: PrayerLibrary.Section) -> some View {
        if let onlyCategory = section.categories.count == 1 ? section.categories[0] : nil {
            VStack(spacing: 0) {
                Divider().overlay(Theme.hairline)
                BrowseLink(.category(onlyCategory, in: section)) {
                    SectionLinkRow(title: section.name, count: section.prayerCount)
                }
                .buttonStyle(.haptic)
            }
            .id(section.name)
        } else {
            expandableSectionNode(section)
        }
    }

    private func expandableSectionNode(_ section: PrayerLibrary.Section) -> some View {
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
                DividedRows(items: section.categories, leadingInset: 32) { category in
                    BrowseLink(.category(category, in: section)) {
                        CategoryRow(category: category)
                    }
                    .buttonStyle(.haptic)
                }
            }
        }
        .id(section.name)
    }

    private var pasteOwnRow: some View {
        BrowseLink(.pasteOwn) {
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
        VStack(alignment: .leading, spacing: 0) {
            DividedRows(items: searchResults) { hit in
                BrowseLink(route(for: hit)) {
                    SearchHitRow(hit: hit)
                }
                .buttonStyle(.haptic)
            }
        }
        .cardSurface(cornerRadius: Radius.group)
    }

    private func route(for hit: SearchHit) -> BrowseRoute {
        guard let excerpt = hit.excerpt else { return .prayer(hit.prayer) }
        return .prayerExcerpt(
            id: hit.prayer.id,
            start: excerpt.rangeInText.lowerBound,
            end: excerpt.rangeInText.upperBound
        )
    }

    private var loadingRow: some View {
        ProgressView()
            .tint(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    private var noResults: some View {
        EmptyNote("No prayers match “\(trimmedQuery)”.")
    }
}

private struct SectionLinkRow: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .appFont(Typography.caption)
                .foregroundStyle(Theme.muted)
                .tracking(0.3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .appFont(Typography.footnote)
                .foregroundStyle(Theme.faint)
            Image(systemName: "chevron.right")
                .appIcon(12, weight: .semibold)
                .foregroundStyle(Theme.muted)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                .appIcon(13, weight: .semibold)
                .foregroundStyle(Theme.muted)
        }
        .padding(.leading, 32)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
