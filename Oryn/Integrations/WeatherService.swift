import Foundation
import CoreLocation

// MARK: - Public types

/// Snapshot of current + near-term conditions, small enough to embed in a card
/// without a full forecast dashboard.
struct WeatherSnapshot: Equatable {
    let summary: String          // e.g. "Clear", "Light rain"
    let symbol: String           // SF Symbol that matches conditions
    let temperatureC: Double
    let feelsLikeC: Double
    let precipitationMM: Double  // Next 1 hour / current reading
    let windKph: Double
    let condition: Condition
    let fetchedAt: Date

    enum Condition: String {
        case clear, cloudy, rain, snow, storm, fog, hot, cold, unknown
    }

    /// Temperature in the unit the current locale uses by default (°C or °F).
    var temperatureDisplay: String {
        let m = Measurement(value: temperatureC, unit: UnitTemperature.celsius)
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: m)
    }

    /// A short one-liner suitable for a planning card ("18° · Light rain").
    var headline: String { "\(temperatureDisplay) · \(summary)" }
}

/// Advice tailored to the day's conditions + task list. Lightweight on purpose
/// — the app shouldn't lecture the user, just nudge.
struct WeatherSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let tone: Tone

    enum Tone { case helpful, warning, positive }
}

// MARK: - Service

/// Fetches current conditions for the user's current location. Uses
/// OpenWeatherMap's current-weather endpoint (free tier) so the app doesn't
/// need Apple's WeatherKit entitlement to be useful.
///
/// When `OPENWEATHER_API_KEY` is missing, the service reports `.unavailable`
/// and the UI shows a subtle "weather unavailable" state rather than breaking.
@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = WeatherService()

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var status: Status = .idle

    enum Status: Equatable {
        case idle
        case fetching
        case unavailable(reason: String)
        case ready
    }

    // MARK: - Cache knobs

    /// Hard cap on how often we'll hit the network. Weather changes slowly and
    /// battery matters more than freshness on this screen.
    private let refreshInterval: TimeInterval = 30 * 60  // 30 minutes

    private let locationManager = CLLocationManager()
    private var pendingLocationContinuation: CheckedContinuation<CLLocation, Error>?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    /// Trigger a fetch if one isn't already in flight and the cache is stale.
    /// Safe to call from `onAppear` — cheap when the cache is warm.
    func refreshIfNeeded() async {
        guard AppConfig.isOpenWeatherConfigured else {
            status = .unavailable(reason: "Weather API key not configured.")
            return
        }
        if let snap = snapshot, Date().timeIntervalSince(snap.fetchedAt) < refreshInterval {
            return
        }
        if case .fetching = status { return }
        await refresh()
    }

    func refresh() async {
        guard AppConfig.isOpenWeatherConfigured else {
            status = .unavailable(reason: "Weather API key not configured.")
            return
        }
        status = .fetching
        do {
            let location = try await currentLocation()
            let snap = try await fetch(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            snapshot = snap
            status = .ready
        } catch {
            status = .unavailable(reason: error.localizedDescription)
        }
    }

    // MARK: - Suggestion surface

    /// Derives up to 2 short, task-aware suggestions from the current snapshot.
    /// Returns an empty array when weather data is not available — callers
    /// should hide the suggestion row in that case.
    func suggestions(forTasks tasks: [OrynTask]) -> [WeatherSuggestion] {
        guard let snap = snapshot else { return [] }
        var out: [WeatherSuggestion] = []

        let titles = tasks.map { $0.title.lowercased() }
        let hasOutdoorWork = titles.contains { $0.hasOutdoorKeyword }
        let hasErrands     = titles.contains { $0.hasErrandKeyword }

        switch snap.condition {
        case .rain, .storm:
            if hasErrands || hasOutdoorWork {
                out.append(.init(
                    icon: "cloud.rain.fill",
                    message: "Rain in the forecast — indoor tasks are a good pick right now.",
                    tone: .helpful
                ))
            }
            if snap.condition == .storm {
                out.append(.init(
                    icon: "cloud.bolt.fill",
                    message: "Storm expected. Consider moving outdoor tasks to a later day.",
                    tone: .warning
                ))
            }
        case .snow:
            out.append(.init(
                icon: "snowflake",
                message: "Snowy conditions — bundle up for anything outside, or swap for an indoor task.",
                tone: .helpful
            ))
        case .hot:
            out.append(.init(
                icon: "thermometer.sun.fill",
                message: "Hot day. Tackle outdoor tasks early, save the heavy lifting for evening.",
                tone: .warning
            ))
        case .cold:
            if hasOutdoorWork {
                out.append(.init(
                    icon: "thermometer.snowflake",
                    message: "Cold out there. Batch outdoor stops to minimise the round trips.",
                    tone: .helpful
                ))
            }
        case .clear:
            if hasOutdoorWork || hasErrands {
                out.append(.init(
                    icon: "sun.max.fill",
                    message: "Clear skies — great time to knock out the outdoor items.",
                    tone: .positive
                ))
            }
        case .cloudy, .fog, .unknown:
            break
        }
        return Array(out.prefix(2))
    }

    // MARK: - Location

    private func currentLocation() async throws -> CLLocation {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return try await waitForLocation()
        case .denied, .restricted:
            throw WeatherError.locationDenied
        case .authorizedWhenInUse, .authorizedAlways:
            if let cached = locationManager.location,
               Date().timeIntervalSince(cached.timestamp) < 600 {
                return cached
            }
            return try await waitForLocation()
        @unknown default:
            throw WeatherError.locationDenied
        }
    }

    private func waitForLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.pendingLocationContinuation = cont
            self.locationManager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else { return }
            self.pendingLocationContinuation?.resume(returning: loc)
            self.pendingLocationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.pendingLocationContinuation?.resume(throwing: error)
            self.pendingLocationContinuation = nil
        }
    }

    // MARK: - Network

    private func fetch(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        components.queryItems = [
            .init(name: "lat", value: String(latitude)),
            .init(name: "lon", value: String(longitude)),
            .init(name: "units", value: "metric"),
            .init(name: "appid", value: AppConfig.openWeatherAPIKey),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.networkFailure
        }
        let decoded = try JSONDecoder().decode(OWMCurrentResponse.self, from: data)
        return WeatherSnapshot(
            summary: decoded.weather.first?.main ?? "Unknown",
            symbol: WeatherService.symbol(for: decoded.weather.first?.id ?? 0,
                                          isDay: decoded.isDaytime),
            temperatureC: decoded.main.temp,
            feelsLikeC: decoded.main.feelsLike,
            precipitationMM: (decoded.rain?.oneHour ?? 0) + (decoded.snow?.oneHour ?? 0),
            windKph: decoded.wind.speed * 3.6,
            condition: WeatherService.condition(for: decoded.weather.first?.id ?? 0,
                                                temperatureC: decoded.main.temp),
            fetchedAt: Date()
        )
    }

    // MARK: - OpenWeather code mapping

    /// Maps OpenWeatherMap's numeric condition codes
    /// (https://openweathermap.org/weather-conditions) to a compact Condition
    /// enum plus an SF Symbol.
    private static func condition(for code: Int, temperatureC: Double) -> WeatherSnapshot.Condition {
        if temperatureC >= 32 { return .hot }
        if temperatureC <= -5 { return .cold }
        switch code {
        case 200..<300: return .storm
        case 300..<600: return .rain
        case 600..<700: return .snow
        case 700..<800: return .fog
        case 800:       return .clear
        case 801..<900: return .cloudy
        default:        return .unknown
        }
    }

    private static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 200..<300: return "cloud.bolt.rain.fill"
        case 300..<500: return "cloud.drizzle.fill"
        case 500..<600: return "cloud.rain.fill"
        case 600..<700: return "cloud.snow.fill"
        case 700..<800: return "cloud.fog.fill"
        case 800:       return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 801:       return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 802..<810: return "cloud.fill"
        default:        return "cloud.fill"
        }
    }
}

// MARK: - OpenWeatherMap response shape

private struct OWMCurrentResponse: Decodable {
    let weather: [OWMWeather]
    let main: OWMMain
    let wind: OWMWind
    let rain: OWMPrecip?
    let snow: OWMPrecip?
    let dt: TimeInterval
    let sys: OWMSys

    var isDaytime: Bool {
        let now = Date(timeIntervalSince1970: dt)
        return now >= Date(timeIntervalSince1970: sys.sunrise)
            && now <= Date(timeIntervalSince1970: sys.sunset)
    }
}

private struct OWMWeather: Decodable {
    let id: Int
    let main: String
    let description: String
}

private struct OWMMain: Decodable {
    let temp: Double
    let feelsLike: Double

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
    }
}

private struct OWMWind: Decodable { let speed: Double }

private struct OWMPrecip: Decodable {
    let oneHour: Double?

    enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

private struct OWMSys: Decodable {
    let sunrise: TimeInterval
    let sunset: TimeInterval
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case locationDenied
    case networkFailure
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .locationDenied:  return "Location permission not granted."
        case .networkFailure:  return "Couldn't reach the weather service."
        case .notConfigured:   return "Weather API key not configured."
        }
    }
}

// MARK: - Keyword helpers (shared across the suggestion surface)

private extension String {
    static let outdoorKeywords: Set<String> = [
        "walk", "run", "jog", "hike", "bike", "cycle", "garden",
        "yard", "park", "outdoor", "outside", "lawn", "mow",
        "shovel", "wash car", "picnic", "beach"
    ]
    static let errandKeywords: Set<String> = [
        "grocery", "groceries", "store", "shop", "shopping", "bank",
        "pick up", "drop off", "pharmacy", "errand", "mail", "post office"
    ]

    var hasOutdoorKeyword: Bool {
        String.outdoorKeywords.contains { self.contains($0) }
    }

    var hasErrandKeyword: Bool {
        String.errandKeywords.contains { self.contains($0) }
    }
}
