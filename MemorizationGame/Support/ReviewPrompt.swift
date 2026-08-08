import Foundation

enum ReviewPrompt {
    static let minimumMemorizedPassages = 2
    static let delayAfterCelebration = Duration.seconds(3.6)

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    static func shouldAsk(memorizedPassageCount: Int, settings: AppSettings) -> Bool {
        memorizedPassageCount >= minimumMemorizedPassages
            && settings.lastReviewRequestVersion != currentVersion
    }
}
