import Foundation
import CoreLocation

struct ZipCode: Codable, Identifiable {
    let zipCode: String
    let city: String
    let stateCode: String
    let lat: Double
    let lon: Double
    let population: Int
    let isInhabited: Bool

    var id: String { zipCode }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var displayName: String {
        "\(city), \(stateCode) \(zipCode)"
    }

    enum CodingKeys: String, CodingKey {
        case zipCode = "zip_code"
        case city
        case stateCode = "state_code"
        case lat
        case lon
        case population
        case isInhabited = "is_inhabited"
    }
}

struct NoteEncounter: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let userId: UUID
    let distanceMiles: Double
    let wasTapped: Bool
    let encounteredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case userId = "user_id"
        case distanceMiles = "distance_miles"
        case wasTapped = "was_tapped"
        case encounteredAt = "encountered_at"
    }
}
