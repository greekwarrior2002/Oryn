import Foundation

/// Google Calendar integration.
///
/// Like `OutlookService`, this ships full architecture minus the platform
/// credentials. To finish wiring:
///   1. Create an OAuth client at https://console.cloud.google.com/ →
///      APIs & Services → Credentials. Choose "iOS" as the application type
///      and register your bundle identifier.
///   2. Paste the resulting Client ID into `Secrets.xcconfig` as
///      `GCAL_CLIENT_ID`.
///   3. Add the `GoogleSignIn-iOS` SPM package and replace the stub in
///      `connect()` with `GIDSignIn.sharedInstance.signIn(...)`.
///   4. Once signed in, the `fetchCandidates()` pipeline already queries
///      `https://www.googleapis.com/calendar/v3/calendars/primary/events`
///      and hands results to the suggestion engine.
@MainActor
final class GoogleCalendarService: NSObject, IntegrationProvider, ObservableObject {

    static let shared = GoogleCalendarService()

    let id = "gcal"
    let displayName = "Google Calendar"
    let icon = "calendar.circle.fill"

    @Published private(set) var connectionState: OutlookService.ConnectionState = .disconnected

    private var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GCAL_CLIENT_ID") as? String) ?? ""
    }
    private let scopes = ["https://www.googleapis.com/auth/calendar.readonly"]

    private override init() { super.init() }

    // MARK: IntegrationProvider

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return IntegrationTokenStore.read(forAccount: "gcal-access") != nil
    }

    func connect() async throws {
        guard !clientID.isEmpty else {
            connectionState = .failed("Missing GCAL_CLIENT_ID")
            throw IntegrationError.notConfigured(
                "Add GCAL_CLIENT_ID to Secrets.xcconfig and register an iOS OAuth client."
            )
        }
        connectionState = .connecting
        // GoogleSignIn call would go here. Until the package is added:
        connectionState = .failed(
            "GoogleSignIn not yet wired. Add the GoogleSignIn-iOS SPM package and replace this stub."
        )
        throw IntegrationError.notConfigured("GoogleSignIn wiring pending.")
    }

    func disconnect() async {
        IntegrationTokenStore.delete(forAccount: "gcal-access")
        IntegrationTokenStore.delete(forAccount: "gcal-refresh")
        connectionState = .disconnected
    }

    func fetchCandidates() async throws -> [IntegrationCandidate] {
        guard isConnected else { throw IntegrationError.notConnected }
        guard let token = IntegrationTokenStore.read(forAccount: "gcal-access") else {
            throw IntegrationError.notConnected
        }
        return try await fetchEvents(token: token)
    }

    // MARK: - Calendar API

    private func fetchEvents(token: String) async throws -> [IntegrationCandidate] {
        let now = ISO8601DateFormatter().string(from: Date())
        let end = ISO8601DateFormatter().string(
            from: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        )
        var comps = URLComponents(string:
            "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        )!
        comps.queryItems = [
            .init(name: "timeMin", value: now),
            .init(name: "timeMax", value: end),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime"),
            .init(name: "maxResults", value: "50")
        ]
        var req = URLRequest(url: comps.url!)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IntegrationError.networkFailure("Google API returned non-2xx")
        }
        let decoded = try JSONDecoder().decode(GCalEventsResponse.self, from: data)
        return decoded.items.map { evt in
            IntegrationCandidate(
                id: evt.id,
                providerID: self.id,
                kind: .calendarEvent,
                title: evt.summary ?? "(untitled event)",
                body: evt.description,
                start: evt.start?.resolvedDate,
                end: evt.end?.resolvedDate,
                deadline: evt.start?.resolvedDate,
                url: evt.htmlLink.flatMap(URL.init(string:))
            )
        }
    }
}

// MARK: - Google response shapes

private struct GCalEventsResponse: Decodable {
    let items: [GCalEvent]
}
private struct GCalEvent: Decodable {
    let id: String
    let summary: String?
    let description: String?
    let htmlLink: String?
    let start: GCalDate?
    let end: GCalDate?
}
private struct GCalDate: Decodable {
    let date: String?
    let dateTime: String?
    var resolvedDate: Date? {
        if let dt = dateTime, let d = ISO8601DateFormatter().date(from: dt) { return d }
        if let d = date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.date(from: d)
        }
        return nil
    }
}
