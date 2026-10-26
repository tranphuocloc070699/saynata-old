import Foundation

/// Build settings from Info.plist (set by Config/*.xcconfig). Read once at start.
struct AppConfig: Sendable {
    let apiBaseURL: URL
    let environment: String
    let sentryDSN: String

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfig {
        func value(_ key: String) -> String {
            bundle.object(forInfoDictionaryKey: key) as? String ?? ""
        }
        guard let url = URL(string: value("API_BASE_URL")), url.scheme != nil else {
            fatalError("API_BASE_URL is missing or wrong in Config/*.xcconfig")
        }
        return AppConfig(apiBaseURL: url, environment: value("APP_ENV"), sentryDSN: value("SENTRY_DSN"))
    }
}
