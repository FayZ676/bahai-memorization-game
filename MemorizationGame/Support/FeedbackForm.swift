import Foundation

enum FeedbackForm {
    enum Kind {
        static let problem = "Problem"
        static let feedback = "Idea"
    }

    private static let formID = "1FAIpQLSe3wZs_Ya_cS4kcqYBTX-fOsLi9MpvD9S90RwKAfWqBt5uEiA"

    private enum Field {
        static let kind = "entry.1700380398"
        static let message = "entry.611281190"
        static let email = "entry.1243171085"
    }

    private static let traceLimit = 4000

    static func submit(kind: String, message: String, email: String, trace: String = "") async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encode([
            Field.kind: kind,
            Field.message: body(message: message, trace: trace),
            Field.email: email
        ])

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return false }
        return (200..<300).contains(status)
    }

    private static func body(message: String, trace: String) -> String {
        var parts = ["\(message)\n\n———\n\(AppInfo.diagnostics)"]
        if !trace.isEmpty {
            parts.append("recitation log\n\(String(trace.prefix(traceLimit)))")
        }
        return parts.joined(separator: "\n\n———\n")
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
}
