import Foundation

/// Outlook / Microsoft 365 integration.
///
/// This file provides the architecture — OAuth sign-in, token storage, a
/// fetch pipeline for calendar events and mail — but intentionally stops
/// short of shipping credentials. The user will need to provide a real
/// Microsoft application Client ID (and redirect URI) to finish wiring it.
///
/// To complete the integration:
///   1. Register an Azure AD app at https://portal.azure.com → App
///      registrations. Use a public-client / native redirect URI of the form
///      `msauth.com.yourbundle://auth`.
///   2. Add your Client ID below (or better, inject via `Secrets.xcconfig`).
///   3. Wire the MSAL iOS SDK (SPM package `microsoft-authentication-library-
///      for-objc`) and replace the stub `beginSignIn` with the SDK call.
///   4. Use Microsoft Graph endpoints:
///        GET /me/calendarView?startDateTime=…&endDateTime=…
///        GET /me/messages?$filter=isRead eq false&$top=25
///      to populate `fetchCandidates()`.
///
/// Everything downstream of `fetchCandidates` — suggestion filtering, the
/// review queue UI, settings toggles, dedup by `externalRef` — is already
/// live, so hooking up MSAL is the only remaining step.
@MainActor
final class OutlookService: NSObject, IntegrationProvider, ObservableObject {

    static let shared = OutlookService()

    let id = "outlook"
    let displayName = "Outlook"
    let icon = "envelope.fill"

    @Published private(set) var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(account: String)
        case failed(String)
    }

    // MARK: Configuration
    //
    // Client ID, redirect URI, and scopes are centralised in `AppConfig` so
    // every integration pulls from the same Secrets.xcconfig → Info.plist
    // pipeline. Leave the key blank to keep the rest of the app working; the
    // `connect()` call will surface a clear "notConfigured" error.
    private var clientID: String { AppConfig.outlookClientID }
    private let redirectURI = AppConfig.outlookRedirectURI
    private let scopes = AppConfig.outlookScopes

    private override init() { super.init() }

    // MARK: IntegrationProvider

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return IntegrationTokenStore.read(forAccount: "outlook-access") != nil
    }

    func connect() async throws {
        guard !clientID.isEmpty else {
            connectionState = .failed("Missing OUTLOOK_CLIENT_ID")
            throw IntegrationError.notConfigured(
                "Add OUTLOOK_CLIENT_ID to Secrets.xcconfig and register a redirect URI."
            )
        }
        connectionState = .connecting
        // MSAL sign-in would go here:
        //   let app = try MSALPublicClientApplication(configuration: .init(clientId: clientID))
        //   let result = try await app.acquireToken(...)
        //   IntegrationTokenStore.save(result.accessToken, forAccount: "outlook-access")
        //   IntegrationTokenStore.save(result.refreshToken, forAccount: "outlook-refresh")
        connectionState = .failed(
            "MSAL not yet wired. Add the microsoft-authentication-library-for-objc SPM package and replace this stub."
        )
        throw IntegrationError.notConfigured("MSAL wiring pending.")
    }

    func disconnect() async {
        IntegrationTokenStore.delete(forAccount: "outlook-access")
        IntegrationTokenStore.delete(forAccount: "outlook-refresh")
        connectionState = .disconnected
    }

    func fetchCandidates() async throws -> [IntegrationCandidate] {
        guard isConnected else { throw IntegrationError.notConnected }
        guard let token = IntegrationTokenStore.read(forAccount: "outlook-access") else {
            throw IntegrationError.notConnected
        }

        async let events = fetchCalendarEvents(token: token)
        async let messages = fetchMessages(token: token)
        let (e, m) = try await (events, messages)
        return e + m
    }

    // MARK: - Graph API

    private func fetchCalendarEvents(token: String) async throws -> [IntegrationCandidate] {
        let start = ISO8601DateFormatter().string(from: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let end = ISO8601DateFormatter().string(from: endDate)
        let url = URL(string:
            "https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=\(start)&endDateTime=\(end)"
        )!
        let items: GraphEventsResponse = try await getJSON(url: url, token: token)
        return items.value.map { evt in
            IntegrationCandidate(
                id: evt.id,
                providerID: self.id,
                kind: .calendarEvent,
                title: evt.subject ?? "(untitled event)",
                body: evt.bodyPreview,
                start: Self.parseGraphDate(evt.start?.dateTime),
                end: Self.parseGraphDate(evt.end?.dateTime),
                deadline: Self.parseGraphDate(evt.start?.dateTime),
                url: evt.webLink.flatMap(URL.init(string:))
            )
        }
    }

    private func fetchMessages(token: String) async throws -> [IntegrationCandidate] {
        let url = URL(string:
            "https://graph.microsoft.com/v1.0/me/messages?$filter=isRead eq false&$top=25"
        )!
        let items: GraphMessagesResponse = try await getJSON(url: url, token: token)
        return items.value.map { msg in
            IntegrationCandidate(
                id: msg.id,
                providerID: self.id,
                kind: .email,
                title: msg.subject ?? "(no subject)",
                body: msg.bodyPreview,
                start: nil, end: nil,
                deadline: nil,
                url: msg.webLink.flatMap(URL.init(string:))
            )
        }
    }

    private func getJSON<T: Decodable>(url: URL, token: String) async throws -> T {
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IntegrationError.networkFailure("Graph returned non-2xx")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func parseGraphDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
                f.timeZone = TimeZone(identifier: "UTC")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = TimeZone(identifier: "UTC")
                return f
            }()
        ]
        for f in formatters {
            if let d = f.date(from: s) { return d }
        }
        return ISO8601DateFormatter().date(from: s)
    }
}

// MARK: - Graph response shapes

private struct GraphEventsResponse: Decodable {
    let value: [GraphEvent]
}
private struct GraphEvent: Decodable {
    let id: String
    let subject: String?
    let bodyPreview: String?
    let webLink: String?
    let start: GraphDate?
    let end: GraphDate?
}
private struct GraphDate: Decodable {
    let dateTime: String?
    let timeZone: String?
}
private struct GraphMessagesResponse: Decodable {
    let value: [GraphMessage]
}
private struct GraphMessage: Decodable {
    let id: String
    let subject: String?
    let bodyPreview: String?
    let webLink: String?
}
