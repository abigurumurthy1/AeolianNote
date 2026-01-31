import Foundation
import CoreLocation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let content: String
    let isAnonymous: Bool
    let originLat: Double
    let originLon: Double
    var currentLat: Double
    var currentLon: Double
    var journeyPath: [JourneyPoint]
    var status: NoteStatus
    let createdAt: Date
    let expiresAt: Date

    // Joined data (optional)
    var senderDisplayName: String?
    var senderAvatarUrl: String?
    var distanceFromUser: Double?

    enum NoteStatus: String, Codable {
        case active
        case caught
        case expired
        case dissolved
    }

    struct JourneyPoint: Codable, Equatable {
        let lat: Double
        let lon: Double
        let timestamp: Date
        let windSpeed: Double?
        let windBearing: Double?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLat, longitude: originLon)
    }

    var currentCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: currentLat, longitude: currentLon)
    }

    var totalDistance: Double {
        guard journeyPath.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<journeyPath.count {
            let from = CLLocation(latitude: journeyPath[i-1].lat, longitude: journeyPath[i-1].lon)
            let to = CLLocation(latitude: journeyPath[i].lat, longitude: journeyPath[i].lon)
            total += from.distance(from: to) / 1609.34 // Convert meters to miles
        }
        return total
    }

    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }

    var isExpired: Bool {
        timeRemaining <= 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case content
        case isAnonymous = "is_anonymous"
        case originLat = "origin_lat"
        case originLon = "origin_lon"
        case currentLat = "current_lat"
        case currentLon = "current_lon"
        case journeyPath = "journey_path"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case senderDisplayName = "sender_display_name"
        case senderAvatarUrl = "sender_avatar_url"
        case distanceFromUser = "distance_from_user"
    }
}

extension Note {
    static func create(content: String, isAnonymous: Bool, senderId: UUID, coordinate: CLLocationCoordinate2D) -> Note {
        let now = Date()
        return Note(
            id: UUID(),
            senderId: senderId,
            content: content,
            isAnonymous: isAnonymous,
            originLat: coordinate.latitude,
            originLon: coordinate.longitude,
            currentLat: coordinate.latitude,
            currentLon: coordinate.longitude,
            journeyPath: [JourneyPoint(lat: coordinate.latitude, lon: coordinate.longitude, timestamp: now, windSpeed: nil, windBearing: nil)],
            status: .active,
            createdAt: now,
            expiresAt: now.addingTimeInterval(72 * 60 * 60) // 72 hours
        )
    }
}
