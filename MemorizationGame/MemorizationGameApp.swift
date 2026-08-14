import SwiftUI

@main
struct MemorizationGameApp: App {
    @State private var store = AppStore()
    @State private var splashFinished = false
    @State private var splashCleared = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppFont.register()
        #if DEBUG
        let problems = AchievementCatalog.problems
        assert(problems.isEmpty, "Broken achievements:\n" + problems.joined(separator: "\n"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LibraryView()
                    .environment(store)
                    .environment(\.fontScale, store.settings.fontSize.scale)
                    .opacity(splashFinished ? 1 : 0)
                    .task { ReminderScheduler.sync(store.settings) }
                    .onChange(of: scenePhase, initial: true) { _, phase in
                        guard phase == .active else { return }
                        store.syncStreakReminder()
                    }

                if !splashCleared {
                    SplashView { splashFinished = true }
                        .opacity(splashFinished ? 0 : 1)
                        .allowsHitTesting(!splashFinished)
                        .zIndex(1)
                }
            }
            .animation(Motion.handoff, value: splashFinished)
            .task(id: splashFinished) {
                guard splashFinished else { return }
                try? await Task.sleep(for: .seconds(Motion.handoffDuration))
                splashCleared = true
            }
            .tint(Theme.accent)
            .preferredColorScheme(store.settings.appTheme.colorScheme)
        }
    }
}
