import Foundation

/// Single source of truth for integration credentials and feature availability.
///
/// Keys flow: `Oryn/Config/Config.xcconfig` (committed defaults, always empty)
/// → `Oryn/Config/Secrets.xcconfig` (gitignored overrides)
/// → Info.plist substitution (`$(KEY)` entries in the target's build settings)
/// → `Bundle.main.object(forInfoDictionaryKey:)`.
///
/// Every service that needs a key reads it through this type so the build-time
/// wiring is consistent and each feature has a clear "is configured" check.
enum AppConfig {

    // MARK: - Integration keys

    static var anthropicAPIKey: String { string(for: "ANTHROPIC_API_KEY") }
    static var outlookClientID: String { string(for: "OUTLOOK_CLIENT_ID") }
    static var googleCalendarClientID: String { string(for: "GCAL_CLIENT_ID") }
    static var openWeatherAPIKey: String { string(for: "OPENWEATHER_API_KEY") }

    // MARK: - Convenience flags
    //
    // Each feature should fall back gracefully when its key is missing. UI
    // surfaces that depend on a key can read `isXConfigured` directly instead
    // of probing the string.

    static var isAnthropicConfigured: Bool   { !anthropicAPIKey.isEmpty }
    static var isOutlookConfigured: Bool     { !outlookClientID.isEmpty }
    static var isGoogleCalConfigured: Bool   { !googleCalendarClientID.isEmpty }
    static var isOpenWeatherConfigured: Bool { !openWeatherAPIKey.isEmpty }

    // MARK: - Static redirect URIs / constants
    //
    // These are public values — not secrets — but kept next to the credentials
    // so every piece of integration config lives in one place.

    static let outlookRedirectURI = "msauth.com.oryn://auth"
    static let outlookScopes      = ["Calendars.Read", "Mail.Read", "User.Read", "offline_access"]
    static let googleCalScopes    = ["https://www.googleapis.com/auth/calendar.readonly"]

    // MARK: - Private

    private static func string(for key: String) -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
