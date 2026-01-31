import Foundation
import Supabase

final class SupabaseClient {
    static let shared = SupabaseClient()

    let client: Supabase.SupabaseClient

    private init() {
        // These should be stored in environment or secure config
        let supabaseUrl = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co")!
        let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "your-anon-key"

        client = Supabase.SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey
        )
    }

    // MARK: - Authentication

    func signUp(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(email: email, password: password)
        guard let userId = response.user?.id else {
            throw SupabaseError.authenticationFailed
        }

        // Create user record
        let user = User(id: userId, email: email)
        try await client.from("users").insert(user).execute()
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(email: email, password: password)
        guard let userId = response.user?.id else {
            throw SupabaseError.authenticationFailed
        }

        return try await fetchUser(id: userId)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getCurrentSession() async -> UUID? {
        try? await client.auth.session.user.id
    }

    // MARK: - User Operations

    func fetchUser(id: UUID) async throws -> User {
        let response: User = try await client.from("users")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return response
    }

    func updateUser(_ user: User) async throws {
        try await client.from("users")
            .update(user)
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    func updateUserLocation(userId: UUID, lat: Double, lon: Double) async throws {
        try await client.from("users")
            .update(["current_lat": lat, "current_lon": lon])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func updatePushToken(userId: UUID, token: String) async throws {
        try await client.from("users")
            .update(["push_token": token])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Note Operations

    func createNote(_ note: Note) async throws -> Note {
        let response: Note = try await client.from("notes")
            .insert(note)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    func fetchActiveNotes(near coordinate: CLLocationCoordinate2D, radiusMiles: Double = 10) async throws -> [Note] {
        // Use PostGIS for radius query
        let response: [Note] = try await client.rpc(
            "get_nearby_notes",
            params: [
                "user_lat": coordinate.latitude,
                "user_lon": coordinate.longitude,
                "radius_miles": radiusMiles
            ]
        ).execute().value
        return response
    }

    func fetchUserNotes(userId: UUID) async throws -> [Note] {
        let response: [Note] = try await client.from("notes")
            .select()
            .eq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func fetchInboxNotes(userId: UUID) async throws -> [Note] {
        // Fetch notes that have encountered this user
        let response: [Note] = try await client.rpc(
            "get_inbox_notes",
            params: ["p_user_id": userId.uuidString]
        ).execute().value
        return response
    }

    func catchNote(noteId: UUID, userId: UUID) async throws {
        try await client.from("notes")
            .update(["status": Note.NoteStatus.caught.rawValue])
            .eq("id", value: noteId.uuidString)
            .execute()

        // Update encounter record
        try await client.from("note_encounters")
            .update(["was_tapped": true])
            .eq("note_id", value: noteId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Update user stats
        try await client.rpc(
            "increment_notes_caught",
            params: ["p_user_id": userId.uuidString]
        ).execute()
    }

    // MARK: - ZIP Code Operations

    func fetchZipCode(_ zipCode: String) async throws -> ZipCode {
        let response: ZipCode = try await client.from("zip_codes")
            .select()
            .eq("zip_code", value: zipCode)
            .single()
            .execute()
            .value
        return response
    }

    func searchZipCodes(query: String) async throws -> [ZipCode] {
        let response: [ZipCode] = try await client.from("zip_codes")
            .select()
            .or("zip_code.ilike.\(query)%,city.ilike.\(query)%")
            .limit(10)
            .execute()
            .value
        return response
    }

    // MARK: - Realtime Subscriptions

    func subscribeToNoteEncounters(userId: UUID, onEncounter: @escaping (NoteEncounter) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("note_encounters:\(userId)")

        Task {
            await channel.onPostgresChange(
                event: .insert,
                schema: "public",
                table: "note_encounters",
                filter: "user_id=eq.\(userId.uuidString)"
            ) { change in
                if let encounter = try? change.decodeRecord(as: NoteEncounter.self, decoder: JSONDecoder()) {
                    onEncounter(encounter)
                }
            }

            await channel.subscribe()
        }

        return channel
    }
}

enum SupabaseError: LocalizedError {
    case authenticationFailed
    case userNotFound
    case networkError
    case invalidData

    var errorDescription: String? {
        switch self {
        case .authenticationFailed: return "Authentication failed"
        case .userNotFound: return "User not found"
        case .networkError: return "Network error"
        case .invalidData: return "Invalid data"
        }
    }
}

import CoreLocation
