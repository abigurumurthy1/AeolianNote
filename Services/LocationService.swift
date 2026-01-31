import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdatingLocation = false

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    func getCurrentLocation() async throws -> CLLocation {
        // Return cached location if recent (within 5 minutes)
        if let location = currentLocation,
           Date().timeIntervalSince(location.timestamp) < 300 {
            return location
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Calculate distance between two coordinates in miles
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1609.34 // Convert meters to miles
    }

    /// Check if a coordinate is within a radius (in miles) of another coordinate
    static func isWithinRadius(
        coordinate: CLLocationCoordinate2D,
        of center: CLLocationCoordinate2D,
        radiusMiles: Double
    ) -> Bool {
        return distance(from: coordinate, to: center) <= radiusMiles
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = locationContinuation {
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if isUpdatingLocation {
                locationManager.startUpdatingLocation()
            }
        }
    }
}

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Location access not authorized"
        case .locationUnavailable: return "Location unavailable"
        }
    }
}
