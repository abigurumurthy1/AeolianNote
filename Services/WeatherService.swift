import Foundation
import CoreLocation

actor WeatherService {
    static let shared = WeatherService()

    private let apiKey: String
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private var cache: [String: WindCache] = [:]

    private init() {
        self.apiKey = ProcessInfo.processInfo.environment["OPENWEATHERMAP_API_KEY"] ?? "your-api-key"
    }

    func getWindData(for coordinate: CLLocationCoordinate2D) async throws -> WindData {
        let regionKey = makeRegionKey(coordinate)

        // Check cache
        if let cached = cache[regionKey], !cached.isExpired {
            return cached.windData
        }

        // Fetch from API
        let windData = try await fetchWindData(for: coordinate)

        // Cache for 30 minutes
        let windCache = WindCache(
            regionKey: regionKey,
            windSpeedMph: windData.windSpeedMph,
            windBearingDegrees: windData.windBearingDegrees,
            expiresAt: Date().addingTimeInterval(30 * 60)
        )
        cache[regionKey] = windCache

        return windData
    }

    private func fetchWindData(for coordinate: CLLocationCoordinate2D) async throws -> WindData {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "imperial")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let wind = json?["wind"] as? [String: Any],
              let speed = wind["speed"] as? Double else {
            throw WeatherError.invalidResponse
        }

        // Wind direction (meteorological degrees, 0 = North)
        let bearing = wind["deg"] as? Double ?? 0

        return WindData(
            windSpeedMph: speed,
            windBearingDegrees: bearing,
            timestamp: Date()
        )
    }

    /// Creates a 1-degree grid region key for caching
    private func makeRegionKey(_ coordinate: CLLocationCoordinate2D) -> String {
        let latGrid = Int(coordinate.latitude.rounded())
        let lonGrid = Int(coordinate.longitude.rounded())
        return "\(latGrid),\(lonGrid)"
    }

    func clearCache() {
        cache.removeAll()
    }
}

enum WeatherError: LocalizedError {
    case apiError
    case invalidResponse
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .apiError: return "Weather API error"
        case .invalidResponse: return "Invalid weather response"
        case .rateLimited: return "Weather API rate limited"
        }
    }
}
