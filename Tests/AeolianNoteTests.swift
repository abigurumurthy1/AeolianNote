import XCTest
@testable import AeolianNote
import CoreLocation

final class WindDataTests: XCTestCase {

    func testWindDriftCalculation() {
        // Given: A note at NYC with 10 mph wind blowing East (90 degrees)
        let windData = WindData(
            windSpeedMph: 10,
            windBearingDegrees: 90, // East
            timestamp: Date()
        )

        let startCoord = CLLocationCoordinate2D(
            latitude: 40.7128,
            longitude: -74.0060
        )

        // When: Calculate drift for 1 hour
        let newCoord = windData.calculateDrift(
            from: startCoord,
            duration: 3600, // 1 hour in seconds
            driftFactor: 0.15
        )

        // Then: Note should have moved east
        // At 15% of 10 mph for 1 hour = 1.5 miles
        XCTAssertGreaterThan(newCoord.longitude, startCoord.longitude, "Note should move east (higher longitude)")
        XCTAssertEqual(newCoord.latitude, startCoord.latitude, accuracy: 0.01, "Latitude should stay roughly the same")

        // Calculate actual distance
        let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
        let endLocation = CLLocation(latitude: newCoord.latitude, longitude: newCoord.longitude)
        let distanceMeters = startLocation.distance(from: endLocation)
        let distanceMiles = distanceMeters / 1609.34

        XCTAssertEqual(distanceMiles, 1.5, accuracy: 0.1, "Distance should be approximately 1.5 miles")
    }

    func testWindDriftNorth() {
        // Given: Wind blowing North (0/360 degrees)
        let windData = WindData(
            windSpeedMph: 20,
            windBearingDegrees: 0,
            timestamp: Date()
        )

        let startCoord = CLLocationCoordinate2D(latitude: 35.0, longitude: -100.0)

        // When: Calculate drift for 15 minutes
        let newCoord = windData.calculateDrift(
            from: startCoord,
            duration: 900, // 15 minutes
            driftFactor: 0.15
        )

        // Then: Note should move north (higher latitude)
        XCTAssertGreaterThan(newCoord.latitude, startCoord.latitude)
        XCTAssertEqual(newCoord.longitude, startCoord.longitude, accuracy: 0.001)
    }

    func testWindDriftSouthWest() {
        // Given: Wind blowing Southwest (225 degrees)
        let windData = WindData(
            windSpeedMph: 15,
            windBearingDegrees: 225,
            timestamp: Date()
        )

        let startCoord = CLLocationCoordinate2D(latitude: 40.0, longitude: -90.0)

        // When: Calculate drift
        let newCoord = windData.calculateDrift(
            from: startCoord,
            duration: 3600,
            driftFactor: 0.15
        )

        // Then: Note should move southwest
        XCTAssertLessThan(newCoord.latitude, startCoord.latitude, "Should move south")
        XCTAssertLessThan(newCoord.longitude, startCoord.longitude, "Should move west")
    }

    func testZeroWindSpeed() {
        // Given: No wind
        let windData = WindData(
            windSpeedMph: 0,
            windBearingDegrees: 45,
            timestamp: Date()
        )

        let startCoord = CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0)

        // When: Calculate drift
        let newCoord = windData.calculateDrift(
            from: startCoord,
            duration: 3600,
            driftFactor: 0.15
        )

        // Then: Note should not move
        XCTAssertEqual(newCoord.latitude, startCoord.latitude, accuracy: 0.0001)
        XCTAssertEqual(newCoord.longitude, startCoord.longitude, accuracy: 0.0001)
    }
}

final class NoteTests: XCTestCase {

    func testNoteCreation() {
        let userId = UUID()
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

        let note = Note.create(
            content: "Hello, wind!",
            isAnonymous: false,
            senderId: userId,
            coordinate: coordinate
        )

        XCTAssertEqual(note.content, "Hello, wind!")
        XCTAssertFalse(note.isAnonymous)
        XCTAssertEqual(note.senderId, userId)
        XCTAssertEqual(note.status, .active)
        XCTAssertEqual(note.journeyPath.count, 1)
        XCTAssertFalse(note.isExpired)
    }

    func testNoteTotalDistance() {
        var note = Note.create(
            content: "Test",
            isAnonymous: true,
            senderId: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0)
        )

        // Add journey points
        note.journeyPath.append(Note.JourneyPoint(
            lat: 40.01,
            lon: -100.0,
            timestamp: Date(),
            windSpeed: 10,
            windBearing: 0
        ))

        note.journeyPath.append(Note.JourneyPoint(
            lat: 40.02,
            lon: -100.0,
            timestamp: Date(),
            windSpeed: 10,
            windBearing: 0
        ))

        // Total distance should be approximately 1.38 miles (0.02 degrees ≈ 1.38 miles)
        XCTAssertGreaterThan(note.totalDistance, 1.0)
        XCTAssertLessThan(note.totalDistance, 2.0)
    }

    func testNoteExpiration() {
        var note = Note.create(
            content: "Test",
            isAnonymous: true,
            senderId: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0)
        )

        XCTAssertFalse(note.isExpired)
        XCTAssertGreaterThan(note.timeRemaining, 0)
    }
}

final class LocationServiceTests: XCTestCase {

    func testDistanceCalculation() {
        // NYC to Boston is approximately 190 miles
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let boston = CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)

        let distance = LocationService.distance(from: nyc, to: boston)

        XCTAssertEqual(distance, 190, accuracy: 10, "NYC to Boston should be ~190 miles")
    }

    func testWithinRadius() {
        let center = CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0)
        let nearby = CLLocationCoordinate2D(latitude: 40.05, longitude: -100.0) // ~3.5 miles
        let faraway = CLLocationCoordinate2D(latitude: 41.0, longitude: -100.0) // ~69 miles

        XCTAssertTrue(LocationService.isWithinRadius(coordinate: nearby, of: center, radiusMiles: 10))
        XCTAssertFalse(LocationService.isWithinRadius(coordinate: faraway, of: center, radiusMiles: 10))
    }
}
