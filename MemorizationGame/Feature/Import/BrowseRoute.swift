import SwiftUI

/// Every page of the browse/import flow, addressed by plain values rather than
/// by the model objects behind them, so any screen can link straight to one
/// without holding the library in hand.
enum BrowseRoute: Hashable {
    case browse
    case section(String)
    case category(section: String, name: String)
    case prayer(Int)
    case prayerExcerpt(id: Int, start: Int, end: Int)
    case pasteOwn
    case importPrayer(Int)
    case savedWriting(UUID)
    case savedWritings
    case recentlyRead
    case importText(title: String, content: String)
}

extension BrowseRoute {
    static func prayer(_ prayer: Prayer) -> BrowseRoute {
        .prayer(prayer.id)
    }

    static func category(_ category: PrayerLibrary.Category, in section: PrayerLibrary.Section) -> BrowseRoute {
        .category(section: section.name, name: category.name)
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .browse:
            PrayerBrowseView()
        case .section(let name):
            PrayerBrowseView(focusSection: name)
        case .category(let section, let name):
            if let category = PrayerLibrary.category(named: name, inSection: section) {
                PrayerCategoryView(category: category)
            } else {
                PrayerBrowseView(focusSection: section)
            }
        case .prayer(let id):
            if let prayer = PrayerLibrary.prayer(id: id) {
                PrayerDetailView(prayer: prayer)
            } else {
                PrayerBrowseView()
            }
        case .prayerExcerpt(let id, let start, let end):
            if let prayer = PrayerLibrary.prayer(id: id) {
                PrayerDetailView(prayer: prayer, highlight: start..<end)
            } else {
                PrayerBrowseView()
            }
        case .pasteOwn:
            ImportView()
        case .savedWriting(let id):
            SavedWritingDetailView(writingID: id)
        case .savedWritings:
            SavedWritingsView()
        case .recentlyRead:
            RecentlyReadView()
        case .importText(let title, let content):
            ImportView(initialTitle: title, initialContent: content)
        case .importPrayer(let id):
            if let prayer = PrayerLibrary.prayer(id: id) {
                ImportView(
                    initialTitle: prayer.title,
                    initialContent: prayer.text,
                    author: prayer.author,
                    section: prayer.section,
                    sourceID: prayer.id
                )
            } else {
                ImportView()
            }
        }
    }
}

extension View {
    /// Installs every browse page on the enclosing stack. A screen that calls
    /// this can host a `BrowseLink` to anywhere in the library.
    func browseDestinations() -> some View {
        navigationDestination(for: BrowseRoute.self) { $0.destination }
    }
}

/// A link to any browse page. Deliberately unstyled — call sites keep their own
/// button style, as the header icons and list rows want different ones.
struct BrowseLink<Label: View>: View {
    private let route: BrowseRoute
    private let label: Label

    init(_ route: BrowseRoute, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }

    var body: some View {
        NavigationLink(value: route) { label }
    }
}
