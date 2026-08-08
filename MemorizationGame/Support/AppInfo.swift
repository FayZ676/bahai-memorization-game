import Foundation
import UIKit

enum AppInfo {
    static let privacyPolicy = URL(string: "https://fayz676.github.io/bahai-memorization-game/privacy.html")!

    static var name: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Verses"
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var releaseSummary: String { "\(name) \(version) (\(build))" }

    static var diagnostics: String {
        "\(releaseSummary) · \(deviceIdentifier) · iOS \(UIDevice.current.systemVersion)"
    }

    private static var deviceIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
    }
}
