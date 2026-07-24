import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()

    init() {
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                .environment(\.fontScale, store.settings.fontSize.scale)
                .tint(Theme.accent)
                .preferredColorScheme(store.settings.appTheme.colorScheme)
                .task { ReminderScheduler.sync(store.settings) }
        }
    }
}
