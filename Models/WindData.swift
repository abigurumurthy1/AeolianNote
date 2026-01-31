import Foundation
import CoreLocation

struct WindData: Codable {
    let windSpeedMph: Double
    let windBearingDegrees: Double
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case windSpeedMph = "wind_speed_mph"
        case windBearingDegrees = "wind_bearing_degrees"
        case timestamp
    }

    /// Calculates the new position after drifting for a given time interval
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - duration: Time interval in seconds
    ///   - driftFactor: Percentage of wind speed (default 0.15 = 15%)
    /// - Returns: New coordinate after drift
    func calculateDrift(
        from coordinate: CLLocationCoordinate2D,
        duration: TimeInterval,
        driftFactor: Double = 0.15
    ) -> CLLocationCoordinate2D {
        // Convert wind speed from mph to miles per second
        let speedMilesPerSecond = windSpeedMph / 3600.0

        // Apply drift factor (notes move at 15% of wind speed)
        let effectiveSpeed = speedMilesPerSecond * driftFactor

        // Distance traveled in miles
        let distanceMiles = effectiveSpeed * duration

        // Convert miles to meters (for calculation)
        let distanceMeters = distanceMiles * 1609.34

        // Earth's radius in meters
        let earthRadius = 6371000.0

        // Convert bearing to radians
        let bearingRadians = windBearingDegrees * .pi / 180.0

        // Convert current position to radians
        let lat1 = coordinate.latitude * .pi / 180.0
        let lon1 = coordinate.longitude * .pi / 180.0

        // Angular distance
        let angularDistance = distanceMeters / earthRadius

        // Calculate new position using Haversine forward projection
        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearingRadians)
        )

        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        // Convert back to degrees
        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
}

struct WindCache: Codable {
    let regionKey: String
    let windSpeedMph: Double
    let windBearingDegrees: Double
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case regionKey = "region_key"
        case windSpeedMph = "wind_speed_mph"
        case windBearingDegrees = "wind_bearing_degrees"
        case expiresAt = "expires_at"
    }

    var windData: WindData {
        WindData(
            windSpeedMph: windSpeedMph,
            windBearingDegrees: windBearingDegrees,
            timestamp: Date()
        )
    }

    var isExpired: Bool {
        Date() > expiresAt
    }
}
