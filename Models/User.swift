import Foundation
import CoreLocation

struct User: Codable, Identifiable {
    let id: UUID
    var email: String
    var displayName: String?
    var avatarUrl: String?
    var homeZipCode: String?
    var usesLiveLocation: Bool
    var currentLat: Double?
    var currentLon: Double?
    var pushToken: String?
    var stats: UserStats
    let createdAt: Date

    struct UserStats: Codable {
        var notesLaunched: Int
        var notesCaught: Int
        var totalMilesTraveled: Double
        var longestJourney: Double

        init(notesLaunched: Int = 0, notesCaught: Int = 0, totalMilesTraveled: Double = 0, longestJourney: Double = 0) {
            self.notesLaunched = notesLaunched
            self.notesCaught = notesCaught
            self.totalMilesTraveled = totalMilesTraveled
            self.longestJourney = longestJourney
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = currentLat, let lon = currentLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case homeZipCode = "home_zip_code"
        case usesLiveLocation = "uses_live_location"
        case currentLat = "current_lat"
        case currentLon = "current_lon"
        case pushToken = "push_token"
        case stats
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarUrl = nil
        self.homeZipCode = nil
        self.usesLiveLocation = false
        self.currentLat = nil
        self.currentLon = nil
        self.pushToken = nil
        self.stats = UserStats()
        self.createdAt = Date()
    }
}
