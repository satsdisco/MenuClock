import Foundation

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .celsius:    return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }
    var symbol: String {
        switch self {
        case .celsius:    return "°C"
        case .fahrenheit: return "°F"
        }
    }
    var apiParam: String {
        switch self {
        case .celsius:    return "celsius"
        case .fahrenheit: return "fahrenheit"
        }
    }
}

/// A lightweight current-weather snapshot per city.
struct WeatherSnapshot: Equatable {
    let temperature: Double
    let weatherCode: Int   // WMO code (0–99)
    let unit: TemperatureUnit
    let fetchedAt: Date

    /// SF Symbol name chosen from the WMO weather code.
    /// Reference: https://open-meteo.com/en/docs (WMO code table)
    var sfSymbol: String {
        switch weatherCode {
        case 0:            return "sun.max.fill"
        case 1:            return "sun.max.fill"
        case 2:            return "cloud.sun.fill"
        case 3:            return "cloud.fill"
        case 45, 48:       return "cloud.fog.fill"
        case 51, 53, 55:   return "cloud.drizzle.fill"
        case 56, 57:       return "cloud.sleet.fill"
        case 61, 63:       return "cloud.rain.fill"
        case 65:           return "cloud.heavyrain.fill"
        case 66, 67:       return "cloud.sleet.fill"
        case 71, 73:       return "cloud.snow.fill"
        case 75:           return "snowflake"
        case 77:           return "snowflake"
        case 80, 81:       return "cloud.rain.fill"
        case 82:           return "cloud.heavyrain.fill"
        case 85, 86:       return "cloud.snow.fill"
        case 95:           return "cloud.bolt.rain.fill"
        case 96, 99:       return "cloud.bolt.rain.fill"
        default:           return "questionmark.circle"
        }
    }

    var formattedTemperature: String {
        "\(Int(temperature.rounded()))\(unit.symbol)"
    }
}

/// Fetches current weather for a set of coordinates using Open-Meteo.
///
/// Open-Meteo is free, requires no API key, and does not track usage beyond
/// rate limits. https://open-meteo.com
///
/// Results are cached per clock ID for 15 minutes to stay friendly and to
/// keep the UI snappy on repeated dropdown opens.
@MainActor
final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published private(set) var snapshots: [UUID: WeatherSnapshot] = [:]

    private let cacheLifetime: TimeInterval = 15 * 60
    private var refreshTimer: Timer?
    private var inFlight: Set<UUID> = []

    private init() {
        let t = Timer(timeInterval: cacheLifetime, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
        refreshTimer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func snapshot(for clock: WorldClock) -> WeatherSnapshot? {
        snapshots[clock.id]
    }

    /// Refresh all enabled clocks in parallel. No-op for clocks without
    /// coordinates. Respects the in-memory cache unless `force` is true.
    ///
    /// When `clocks` is nil, fetches for the synthetic local clock + every
    /// user-added world clock so the dropdown is always complete.
    func refreshAll(clocks: [WorldClock]? = nil, force: Bool = false) async {
        let settings = SettingsManager.shared
        guard settings.weatherEnabled else { return }

        let list = clocks ?? ([settings.localClock] + settings.worldClocks)
        let unit = settings.temperatureUnit

        await withTaskGroup(of: (UUID, WeatherSnapshot?).self) { group in
            for clock in list {
                guard let lat = clock.latitude, let lng = clock.longitude else { continue }
                if !force, let cached = snapshots[clock.id],
                   Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime,
                   cached.unit == unit {
                    continue
                }
                if inFlight.contains(clock.id) { continue }
                inFlight.insert(clock.id)
                let clockID = clock.id
                group.addTask {
                    let snap = await Self.fetch(lat: lat, lng: lng, unit: unit)
                    return (clockID, snap)
                }
            }

            for await (clockID, snap) in group {
                inFlight.remove(clockID)
                if let snap {
                    snapshots[clockID] = snap
                }
            }
        }
    }

    // Backgrounded self-scheduled refresh (timer path).
    private func refreshAll() async {
        await refreshAll(clocks: nil, force: false)
    }

    // MARK: - Networking

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }

    private static func fetch(lat: Double, lng: Double, unit: TemperatureUnit) async -> WeatherSnapshot? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", lng)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: unit.apiParam),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = comps?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return WeatherSnapshot(
                temperature: decoded.current.temperature_2m,
                weatherCode: decoded.current.weather_code,
                unit: unit,
                fetchedAt: Date()
            )
        } catch {
            return nil
        }
    }
}
