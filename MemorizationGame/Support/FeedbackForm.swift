import Foundation
import UIKit

enum FeedbackForm {
    private static let formID = "1FAIpQLSe3wZs_Ya_cS4kcqYBTX-fOsLi9MpvD9S90RwKAfWqBt5uEiA"

    private enum Field {
        static let kind = "entry.1700380398"
        static let message = "entry.611281190"
        static let email = "entry.1243171085"
    }

    static var diagnostics: String {
        "\(appName) \(version) (\(build)) · \(deviceIdentifier) · iOS \(UIDevice.current.systemVersion)"
    }

    static func submit(kind: String, message: String, email: String) async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encode([
            Field.kind: kind,
            Field.message: "\(message)\n\n———\n\(diagnostics)",
            Field.email: email
        ])

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return false }
        return (200..<300).contains(status)
    }

    private static var endpoint: URL {
        URL(string: "https://docs.google.com/forms/d/e/\(formID)/formResponse")!
    }

    private static func encode(_ fields: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields
            .filter { !$0.value.isEmpty }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private static var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Verses"
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private static var deviceIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
    }
}
