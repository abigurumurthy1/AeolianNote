//
//  ContentView.swift
//  Aeolian Note
//
//  A digital "message in a bottle" app with real Supabase backend
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Configuration
struct Config {
    static let supabaseURL = "https://aglusmalwdoegxizcjcv.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFnbHVzbWFsd2RvZWd4aXpjamN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5MDc2NDQsImV4cCI6MjA4NTQ4MzY0NH0.SNWpvG47J7CpknFnaHF5po1knCSmTIPvxwWg8BCSUSA"
    static let openWeatherMapKey = "87220fd9d66c034245c80f90a0840e02"
    static let radiusMiles = 10.0
}

// MARK: - Supabase REST API Client
class SupabaseAPI {
    static let shared = SupabaseAPI()

    private var accessToken: String?
    private var currentUserId: String?

    private init() {}

    var isAuthenticated: Bool { accessToken != nil }
    var userId: String? { currentUserId }

    // MARK: - Auth
    func signUp(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        if let token = response.access_token, let userId = response.user?.id {
            self.accessToken = token
            self.currentUserId = userId
            try await createUserRecord(userId: userId, email: email)
        }

        return response
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        if let token = response.access_token, let userId = response.user?.id {
            self.accessToken = token
            self.currentUserId = userId
            try await ensureUserRecord(userId: userId, email: email)
        }

        return response
    }

    private func createUserRecord(userId: String, email: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "id": userId,
            "email": email,
            "display_name": email.components(separatedBy: "@").first ?? "User"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 && httpResponse.statusCode != 409 {
            throw APIError.serverError("Failed to create user record")
        }
    }

    private func ensureUserRecord(userId: String, email: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "id": userId,
            "email": email,
            "display_name": email.components(separatedBy: "@").first ?? "User"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    func signOut() {
        accessToken = nil
        currentUserId = nil
    }

    // MARK: - Notes
    func createNote(content: String, isAnonymous: Bool, lat: Double, lon: Double) async throws -> Note {
        guard let userId = currentUserId, let token = accessToken else {
            throw APIError.notAuthenticated
        }

        let url = URL(string: "\(Config.supabaseURL)/rest/v1/notes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(72 * 3600))

        let body: [String: Any] = [
            "sender_id": userId,
            "content": content,
            "is_anonymous": isAnonymous,
            "origin_lat": lat,
            "origin_lon": lon,
            "current_lat": lat,
            "current_lon": lon,
            "status": "active",
            "expires_at": expiresAt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        let notes = try JSONDecoder().decode([Note].self, from: data)
        guard let note = notes.first else { throw APIError.invalidResponse }
        return note
    }

    func fetchActiveNotes() async throws -> [Note] {
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/notes?status=eq.active&select=*")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([Note].self, from: data)
    }

    func fetchUserNotes() async throws -> [Note] {
        guard let userId = currentUserId, let token = accessToken else {
            throw APIError.notAuthenticated
        }

        let url = URL(string: "\(Config.supabaseURL)/rest/v1/notes?sender_id=eq.\(userId)&select=*&order=created_at.desc")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([Note].self, from: data)
    }
}

// MARK: - Weather & Geocoding API
class WeatherAPI {
    static let shared = WeatherAPI()

    func getWind(lat: Double, lon: Double) async throws -> WindData {
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(Config.openWeatherMapKey)&units=imperial")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let wind = json?["wind"] as? [String: Any],
              let speed = wind["speed"] as? Double else {
            throw APIError.invalidResponse
        }

        let bearing = wind["deg"] as? Double ?? 0
        return WindData(speed: speed, bearing: bearing)
    }

    func geocodeZipCode(_ zipCode: String) async throws -> CLLocationCoordinate2D {
        let url = URL(string: "https://api.openweathermap.org/geo/1.0/zip?zip=\(zipCode),US&appid=\(Config.openWeatherMapKey)")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let lat = json?["lat"] as? Double,
              let lon = json?["lon"] as? Double else {
            throw APIError.serverError("Invalid zip code")
        }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Models
struct AuthResponse: Codable {
    let access_token: String?
    let user: AuthUser?
    let error: String?
    let error_description: String?
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

struct Note: Codable, Identifiable, Equatable {
    let id: String
    let sender_id: String
    let content: String
    let is_anonymous: Bool
    let origin_lat: Double
    let origin_lon: Double
    let current_lat: Double
    let current_lon: Double
    let status: String
    let created_at: String?
    let expires_at: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: current_lat, longitude: current_lon)
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

struct WindData {
    let speed: Double
    let bearing: Double
}

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in again."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Distance Calculation
func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return fromLocation.distance(from: toLocation) / 1609.34 // Convert meters to miles
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var allNotes: [Note] = []
    @Published var userNotes: [Note] = []
    @Published var windData: WindData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocationCoordinate2D?

    // Zip code and location
    @Published var zipCode: String = "" {
        didSet {
            UserDefaults.standard.set(zipCode, forKey: "userZipCode")
        }
    }
    @Published var zipCodeLocation: CLLocationCoordinate2D?

    // Opened notes tracking
    @Published var openedNoteIds: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(openedNoteIds), forKey: "openedNoteIds")
        }
    }

    init() {
        zipCode = UserDefaults.standard.string(forKey: "userZipCode") ?? ""
        openedNoteIds = Set(UserDefaults.standard.stringArray(forKey: "openedNoteIds") ?? [])
    }

    // Sample notes for demo (generated around user's location)
    @Published var sampleNotes: [Note] = []

    // All visible notes (real + sample)
    var allVisibleNotes: [Note] {
        allNotes + sampleNotes
    }

    // Notes within user's radius (excluding user's own notes)
    var notesInRadius: [Note] {
        guard let userLoc = zipCodeLocation ?? userLocation else { return [] }
        let userId = SupabaseAPI.shared.userId

        return allVisibleNotes.filter { note in
            note.sender_id != userId &&
            calculateDistance(from: userLoc, to: note.coordinate) <= Config.radiusMiles
        }
    }

    // Received notes (only notes that have been opened from Discover)
    var receivedNotes: [Note] {
        notesInRadius.filter { isNoteOpened($0) }
    }

    // Sent notes (user's own)
    var sentNotes: [Note] {
        userNotes
    }

    func isNoteOpened(_ note: Note) -> Bool {
        openedNoteIds.contains(note.id)
    }

    func markNoteAsOpened(_ note: Note) {
        openedNoteIds.insert(note.id)
    }

    func checkAuth() {
        isAuthenticated = SupabaseAPI.shared.isAuthenticated
    }

    func signIn(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let response = try await SupabaseAPI.shared.signIn(email: email, password: password)
            if response.error != nil {
                await MainActor.run { errorMessage = response.error_description ?? "Sign in failed" }
            } else {
                await MainActor.run { isAuthenticated = true }
                await loadData()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func signUp(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let response = try await SupabaseAPI.shared.signUp(email: email, password: password)
            if response.error != nil {
                await MainActor.run { errorMessage = response.error_description ?? "Sign up failed" }
            } else {
                await MainActor.run {
                    isAuthenticated = true
                    errorMessage = "Account created! You may need to verify your email."
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func signOut() {
        SupabaseAPI.shared.signOut()
        isAuthenticated = false
        allNotes = []
        userNotes = []
        sampleNotes = []
    }

    func clearAllData() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "userZipCode")
        UserDefaults.standard.removeObject(forKey: "openedNoteIds")

        // Reset in-memory state
        zipCode = ""
        zipCodeLocation = nil
        openedNoteIds = []
        sampleNotes = []
    }

    func loadData() async {
        do {
            let fetchedNotes = try await SupabaseAPI.shared.fetchActiveNotes()
            await MainActor.run { allNotes = fetchedNotes }

            if SupabaseAPI.shared.isAuthenticated {
                let myNotes = try await SupabaseAPI.shared.fetchUserNotes()
                await MainActor.run { userNotes = myNotes }
            }

            // Geocode zip code if set
            if !zipCode.isEmpty {
                await geocodeZip()
            }

            // Generate sample notes if we have a location but no sample notes
            await MainActor.run {
                if let loc = zipCodeLocation, sampleNotes.isEmpty {
                    generateSampleNotes(around: loc)
                }
            }

            // Get wind data for user location or center of US
            let lat = zipCodeLocation?.latitude ?? userLocation?.latitude ?? 39.8283
            let lon = zipCodeLocation?.longitude ?? userLocation?.longitude ?? -98.5795
            let wind = try await WeatherAPI.shared.getWind(lat: lat, lon: lon)
            await MainActor.run { windData = wind }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func geocodeZip() async {
        guard !zipCode.isEmpty, zipCode.count == 5 else { return }

        do {
            let location = try await WeatherAPI.shared.geocodeZipCode(zipCode)
            await MainActor.run {
                zipCodeLocation = location
                // Generate sample notes around this location
                generateSampleNotes(around: location)
            }
        } catch {
            await MainActor.run { errorMessage = "Could not find zip code" }
        }
    }

    func generateSampleNotes(around location: CLLocationCoordinate2D) {
        let sampleMessages = [
            // Morning quotes
            "Rise and shine! Today is full of possibilities.",
            "Good morning! Remember: you are capable of amazing things.",
            "Start your day with gratitude. What are you thankful for?",
            "The early bird catches the worm. But the second mouse gets the cheese!",
            // City happenings
            "Just saw the most amazing sunset from downtown. Wish you were here!",
            "The farmers market this weekend was incredible - fresh strawberries everywhere!",
            "Traffic on Main St is crazy today. Take the back roads if you can!",
            "New coffee shop opened on 5th Ave. The lattes are to die for!",
            "Did anyone else see that double rainbow yesterday? Magical!",
            // Personal notes
            "Having one of those days where everything feels right. Sending good vibes!",
            "Just got promoted at work! Hard work really does pay off.",
            "Missing my hometown today. Anyone else feeling nostalgic?",
            "Made the best coffee this morning. Little things matter.",
            "Finally finished that book I've been reading for months!",
            "Taking a mental health day. Self-care is not selfish.",
            // Philosophical
            "The wind doesn't ask permission. Neither should your dreams.",
            "Every stranger has a story worth hearing.",
            "Life is short. Eat the cake. Buy the shoes. Take the trip.",
            "Be the reason someone smiles today.",
            // Fun observations
            "Saw a dog walking its human today. Made my whole week!",
            "The clouds look like cotton candy. Look up!",
            "Found a four-leaf clover. Sharing the luck with whoever reads this!",
            "Just witnessed a squirrel steal an entire pizza slice. Legend.",
            "Random act of kindness: paid for the person behind me in line!",
            // Encouragement
            "You're doing better than you think you are.",
            "This too shall pass. Keep going!",
            "Sending a virtual hug to whoever needs it right now.",
            "Plot twist: everything works out in the end."
        ]

        var notes: [Note] = []
        let shuffledMessages = sampleMessages.shuffled()

        for i in 0..<18 {
            // Generate random position within 8 miles of user
            let randomDistance = Double.random(in: 0.5...9) // miles
            let randomBearing = Double.random(in: 0...360) // degrees

            // Convert to lat/lon offset
            let latOffset = (randomDistance / 69.0) * cos(randomBearing * .pi / 180)
            let lonOffset = (randomDistance / (69.0 * cos(location.latitude * .pi / 180))) * sin(randomBearing * .pi / 180)

            let noteLat = location.latitude + latOffset
            let noteLon = location.longitude + lonOffset

            let note = Note(
                id: "sample-\(i)-\(UUID().uuidString)",
                sender_id: "sample-sender-\(i)",
                content: shuffledMessages[i % shuffledMessages.count],
                is_anonymous: Bool.random(),
                origin_lat: noteLat,
                origin_lon: noteLon,
                current_lat: noteLat,
                current_lon: noteLon,
                status: "active",
                created_at: ISO8601DateFormatter().string(from: Date()),
                expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(72 * 3600))
            )
            notes.append(note)
        }

        sampleNotes = notes
    }

    func createNote(content: String, isAnonymous: Bool) async -> Bool {
        let lat = zipCodeLocation?.latitude ?? userLocation?.latitude ?? 39.8283
        let lon = zipCodeLocation?.longitude ?? userLocation?.longitude ?? -98.5795

        do {
            let note = try await SupabaseAPI.shared.createNote(
                content: content,
                isAnonymous: isAnonymous,
                lat: lat,
                lon: lon
            )
            await MainActor.run {
                allNotes.insert(note, at: 0)
                userNotes.insert(note, at: 0)
            }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - Design System
struct DesignColors {
    static let parchment = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let ink = Color(red: 0.2, green: 0.15, blue: 0.1)
    static let ocean = Color(red: 0.3, green: 0.5, blue: 0.7)
    static let sunset = Color(red: 0.95, green: 0.6, blue: 0.4)
    static let glow = Color(red: 1.0, green: 0.9, blue: 0.6)
    static let unopenedNote = Color(red: 0.9, green: 0.2, blue: 0.2) // Bright red for unopened notes
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
                    .environmentObject(locationManager)
            } else {
                AuthView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            appState.checkAuth()
            locationManager.requestPermission()
        }
    }
}

// MARK: - Auth View
struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            DesignColors.parchment.ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 60))
                        .foregroundColor(DesignColors.ocean)

                    Text("Aeolian Note")
                        .font(.custom("Baskerville", size: 32))
                        .foregroundColor(DesignColors.ink)

                    Text("Messages carried by the wind")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.ink.opacity(0.6))
                }
                .padding(.top, 60)

                Spacer()

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(ParchmentFieldStyle())
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(ParchmentFieldStyle())

                    if let error = appState.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: submit) {
                        if appState.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(.custom("Baskerville", size: 18))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DesignColors.ocean)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(appState.isLoading)
                }
                .padding(.horizontal, 24)

                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.ocean)
                }

                Spacer()
            }
        }
    }

    func submit() {
        Task {
            if isSignUp {
                await appState.signUp(email: email, password: password)
            } else {
                await appState.signIn(email: email, password: password)
            }
        }
    }
}

struct ParchmentFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignColors.ink.opacity(0.2)))
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WindMapView()
                .tabItem { Label("Discover", systemImage: "wind") }
                .tag(0)

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .tag(1)
                .badge(appState.receivedNotes.count)

            ComposeNoteView()
                .tabItem { Label("Compose", systemImage: "pencil.and.scribble") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(DesignColors.ocean)
        .onAppear {
            Task { await appState.loadData() }
        }
    }
}

// MARK: - Wind Map View
struct WindMapView: View {
    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
        span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
    ))
    @State private var selectedNote: Note?
    @State private var showNoteDetail = false
    @State private var hasInitializedPosition = false

    var body: some View {
        ZStack {
            Map(position: $position) {
                // Show user's location radius if zip code is set
                if let userLoc = appState.zipCodeLocation ?? appState.userLocation {
                    MapCircle(center: userLoc, radius: Config.radiusMiles * 1609.34)
                        .foregroundStyle(DesignColors.ocean.opacity(0.1))
                        .stroke(DesignColors.ocean.opacity(0.5), lineWidth: 2)

                    Annotation("You", coordinate: userLoc) {
                        ZStack {
                            Circle()
                                .fill(DesignColors.ocean)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }
                    }
                }

                // Show notes (real + sample)
                ForEach(appState.allVisibleNotes) { note in
                    let isInRadius = isNoteInUserRadius(note)
                    let isOpened = appState.isNoteOpened(note)
                    let isMine = note.sender_id == SupabaseAPI.shared.userId

                    Annotation("", coordinate: note.coordinate) {
                        NoteMarker(
                            isInRadius: isInRadius,
                            isOpened: isOpened,
                            isMine: isMine
                        )
                        .onTapGesture {
                            if isInRadius && !isMine {
                                selectedNote = note
                                showNoteDetail = true
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                HStack {
                    Spacer()
                    CompassView(
                        bearing: appState.windData?.bearing ?? 0,
                        speed: appState.windData?.speed ?? 0
                    )
                    .padding()
                }
                Spacer()

                // Status bar
                VStack(spacing: 4) {
                    if appState.zipCode.isEmpty {
                        Text("Set your zip code in Profile to discover notes")
                            .font(.system(size: 12))
                            .foregroundColor(DesignColors.ink.opacity(0.6))
                    }

                    HStack(spacing: 16) {
                        Label("\(appState.allVisibleNotes.count) total", systemImage: "doc.text")
                        Label("\(appState.notesInRadius.count) nearby", systemImage: "location.circle")

                        let unopened = appState.notesInRadius.filter { !appState.isNoteOpened($0) }.count
                        if unopened > 0 {
                            Label("\(unopened) to open", systemImage: "envelope.fill")
                                .foregroundColor(DesignColors.unopenedNote)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(DesignColors.parchment.opacity(0.95))
                .cornerRadius(20)
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showNoteDetail) {
            if let note = selectedNote {
                NoteDetailView(note: note, onOpen: {
                    appState.markNoteAsOpened(note)
                }, onDissolve: {
                    // Remove sample note after dissolving
                    if note.id.hasPrefix("sample-") {
                        appState.sampleNotes.removeAll { $0.id == note.id }
                    }
                    showNoteDetail = false
                })
            }
        }
        .onAppear {
            centerOnUserLocation()
        }
        .refreshable {
            await appState.loadData()
        }
        .onChange(of: appState.zipCode) { _, newValue in
            if !newValue.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    centerOnUserLocation()
                }
            }
        }
    }

    func centerOnUserLocation() {
        if let loc = appState.zipCodeLocation {
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                ))
            }
        }
    }

    func isNoteInUserRadius(_ note: Note) -> Bool {
        guard let userLoc = appState.zipCodeLocation ?? appState.userLocation else { return false }
        return calculateDistance(from: userLoc, to: note.coordinate) <= Config.radiusMiles
    }
}

struct NoteMarker: View {
    let isInRadius: Bool
    let isOpened: Bool
    let isMine: Bool
    @State private var pulse = false

    var markerColor: Color {
        if isMine {
            return DesignColors.ocean
        } else if isInRadius && !isOpened {
            return DesignColors.unopenedNote
        } else if isInRadius && isOpened {
            return DesignColors.sunset.opacity(0.6)
        } else {
            return DesignColors.glow.opacity(0.5)
        }
    }

    var shouldPulse: Bool {
        isInRadius && !isOpened && !isMine
    }

    var body: some View {
        ZStack {
            if shouldPulse {
                Circle()
                    .fill(DesignColors.unopenedNote.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulse ? 1.8 : 1.0)
            }

            Circle()
                .fill(RadialGradient(
                    colors: [markerColor, markerColor.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 12
                ))
                .frame(width: isMine ? 14 : (isInRadius ? 20 : 12), height: isMine ? 14 : (isInRadius ? 20 : 12))
                .shadow(color: markerColor.opacity(0.8), radius: isInRadius ? 8 : 3)

            if isInRadius && !isOpened && !isMine {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            if shouldPulse {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

struct CompassView: View {
    let bearing: Double
    let speed: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(DesignColors.ink.opacity(0.3), lineWidth: 2).frame(width: 50, height: 50)
                Image(systemName: "location.north.fill")
                    .foregroundColor(DesignColors.sunset)
                    .rotationEffect(.degrees(bearing))
            }
            Text("\(Int(speed)) mph")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignColors.ink)
        }
        .padding()
        .background(DesignColors.parchment.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Inbox View
struct InboxView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSegment = 0

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.parchment.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented control
                    Picker("", selection: $selectedSegment) {
                        Text("Received (\(appState.receivedNotes.count))").tag(0)
                        Text("Sent (\(appState.sentNotes.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if selectedSegment == 0 {
                        ReceivedNotesView()
                    } else {
                        SentNotesView()
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await appState.loadData()
            }
        }
    }
}

struct ReceivedNotesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.receivedNotes.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "wind")
                    .font(.system(size: 60))
                    .foregroundColor(DesignColors.ink.opacity(0.3))
                Text("No messages yet")
                    .font(.custom("Baskerville", size: 24))
                    .foregroundColor(DesignColors.ink)

                if appState.zipCode.isEmpty {
                    Text("Set your zip code in Profile\nto discover notes on the map")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else if appState.notesInRadius.isEmpty {
                    Text("No notes floating nearby.\nCheck back later!")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 8) {
                        Text("\(appState.notesInRadius.count) notes floating nearby!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignColors.unopenedNote)
                        Text("Go to Discover tab and tap the\nred dots to open messages")
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.ink.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appState.receivedNotes) { note in
                        ReceivedNoteRow(note: note)
                    }
                }
                .padding()
            }
        }
    }
}

struct ReceivedNoteRow: View {
    let note: Note
    @EnvironmentObject var appState: AppState
    @State private var showContent = false

    var isOpened: Bool {
        appState.isNoteOpened(note)
    }

    var body: some View {
        Button(action: {
            showContent = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isOpened ?
                              LinearGradient(colors: [DesignColors.sunset.opacity(0.5), DesignColors.glow.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [DesignColors.unopenedNote, DesignColors.ocean], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: isOpened ? "envelope.open" : "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(note.is_anonymous ? "Anonymous" : "Someone")
                            .font(.custom("Baskerville", size: 16))
                            .foregroundColor(DesignColors.ink)

                        if !isOpened {
                            Text("NEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignColors.unopenedNote)
                                .cornerRadius(4)
                        }
                    }

                    if isOpened {
                        Text(note.content)
                            .font(.system(size: 12))
                            .foregroundColor(DesignColors.ink.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        HStack {
                            Image(systemName: "wind").font(.system(size: 12))
                            Text("Tap to reveal message...")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(DesignColors.ink.opacity(0.5))
                    }
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(DesignColors.ink.opacity(0.3))
            }
            .padding()
            .background(isOpened ? Color.white : Color.white.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: isOpened ? .black.opacity(0.05) : DesignColors.unopenedNote.opacity(0.3), radius: isOpened ? 3 : 8, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOpened ? Color.clear : DesignColors.unopenedNote.opacity(0.5), lineWidth: isOpened ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showContent) {
            NoteDetailView(note: note, onOpen: {
                appState.markNoteAsOpened(note)
            }, onDissolve: {
                // Remove sample note after dissolving
                if note.id.hasPrefix("sample-") {
                    appState.sampleNotes.removeAll { $0.id == note.id }
                }
                showContent = false
            })
        }
    }
}

struct SentNotesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.sentNotes.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "paperplane")
                    .font(.system(size: 60))
                    .foregroundColor(DesignColors.ink.opacity(0.3))
                Text("No notes sent")
                    .font(.custom("Baskerville", size: 24))
                    .foregroundColor(DesignColors.ink)
                Text("Compose a note and float it away!")
                    .font(.system(size: 14))
                    .foregroundColor(DesignColors.ink.opacity(0.6))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appState.sentNotes) { note in
                        SentNoteRow(note: note)
                    }
                }
                .padding()
            }
        }
    }
}

struct SentNoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [DesignColors.ocean, DesignColors.ocean.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .font(.system(size: 14))
                    .foregroundColor(DesignColors.ink)
                    .lineLimit(2)

                HStack {
                    Text(note.status.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(note.status == "active" ? .green : DesignColors.ink.opacity(0.5))

                    if note.is_anonymous {
                        Text("Anonymous")
                            .font(.system(size: 10))
                            .foregroundColor(DesignColors.ink.opacity(0.4))
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
}

struct NoteDetailView: View {
    let note: Note
    var onOpen: () -> Void = {}
    var onDissolve: () -> Void = {}
    @Environment(\.dismiss) var dismiss
    @State private var revealed = false
    @State private var countdown: Int = 10
    @State private var dissolving = false
    @State private var dissolveOpacity: Double = 1.0
    @State private var dissolveScale: Double = 1.0
    @State private var particles: [ParticleData] = []

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DesignColors.parchment.ignoresSafeArea()

            // Dissolve particles
            ForEach(particles) { particle in
                Circle()
                    .fill(DesignColors.glow)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }

            VStack(spacing: 24) {
                Spacer()

                if dissolving {
                    // Dissolving state
                    VStack(spacing: 20) {
                        Image(systemName: "wind")
                            .font(.system(size: 60))
                            .foregroundColor(DesignColors.ocean.opacity(dissolveOpacity))
                            .scaleEffect(dissolveScale)

                        Text("The message dissolves into the wind...")
                            .font(.custom("Baskerville", size: 18))
                            .foregroundColor(DesignColors.ink.opacity(dissolveOpacity))
                    }
                } else if !revealed {
                    // Unopened state
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [DesignColors.unopenedNote, DesignColors.ocean], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)

                            Image(systemName: "envelope.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }

                        Text("A message has drifted to you")
                            .font(.custom("Baskerville", size: 20))
                            .foregroundColor(DesignColors.ink)

                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                revealed = true
                                onOpen()
                            }
                        }) {
                            Text("Open Message")
                                .font(.custom("Baskerville", size: 18))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(DesignColors.ocean)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    // Revealed state with countdown
                    VStack(spacing: 20) {
                        HStack {
                            Spacer()
                            // Countdown timer
                            ZStack {
                                Circle()
                                    .stroke(DesignColors.ink.opacity(0.2), lineWidth: 3)
                                    .frame(width: 50, height: 50)

                                Circle()
                                    .trim(from: 0, to: CGFloat(countdown) / 10.0)
                                    .stroke(countdown <= 3 ? Color.red : DesignColors.ocean, lineWidth: 3)
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(.degrees(-90))

                                Text("\(countdown)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(countdown <= 3 ? .red : DesignColors.ink)
                            }
                        }

                        Image(systemName: "envelope.open")
                            .font(.system(size: 40))
                            .foregroundColor(DesignColors.ocean)

                        Text("Message from the Wind")
                            .font(.custom("Baskerville", size: 24))
                            .foregroundColor(DesignColors.ink)

                        Text(note.content)
                            .font(.custom("Bradley Hand", size: 24))
                            .foregroundColor(DesignColors.ink)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(12)
                            .opacity(dissolveOpacity)
                            .scaleEffect(dissolveScale)

                        Text(note.is_anonymous ? "From: Anonymous" : "From: A fellow traveler")
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.ink.opacity(0.6))

                        Text("Message will dissolve in \(countdown) seconds")
                            .font(.system(size: 12))
                            .foregroundColor(countdown <= 3 ? .red : DesignColors.ink.opacity(0.5))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if !dissolving {
                    Button(revealed ? "Close" : "Cancel") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(revealed ? DesignColors.ocean : DesignColors.ink.opacity(0.2))
                        .foregroundColor(revealed ? .white : DesignColors.ink)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .onReceive(timer) { _ in
            if revealed && !dissolving && countdown > 0 {
                withAnimation {
                    countdown -= 1
                }

                if countdown == 0 {
                    startDissolveAnimation()
                }
            }
        }
        .interactiveDismissDisabled(dissolving)
    }

    func startDissolveAnimation() {
        dissolving = true

        // Create particles
        for i in 0..<20 {
            let particle = ParticleData(
                id: i,
                x: CGFloat.random(in: -100...100),
                y: CGFloat.random(in: -50...50),
                size: CGFloat.random(in: 4...12),
                opacity: 1.0
            )
            particles.append(particle)
        }

        // Animate particles floating away
        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].x += CGFloat.random(in: -150...150)
                particles[i].y += CGFloat.random(in: -200 ... -100)
                particles[i].opacity = 0
            }
            dissolveOpacity = 0
            dissolveScale = 0.5
        }

        // Dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onDissolve()
        }
    }
}

struct ParticleData: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// MARK: - Compose View
struct ComposeNoteView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    @State private var content = ""
    @State private var isAnonymous = false
    @State private var showLaunchAnimation = false
    @State private var isSubmitting = false
    @State private var localError: String?

    let characterLimit = 140

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.parchment.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .trailing) {
                        Text("\(characterLimit - content.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(content.count > 120 ? .red : DesignColors.ink.opacity(0.5))

                        TextEditor(text: $content)
                            .font(.custom("Bradley Hand", size: 20))
                            .foregroundColor(DesignColors.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .onChange(of: content) { oldValue, newValue in
                                if newValue.count > characterLimit {
                                    content = String(newValue.prefix(characterLimit))
                                }
                            }
                    }
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignColors.ink.opacity(0.2), lineWidth: 1))
                    .cornerRadius(12)

                    Toggle(isOn: $isAnonymous) {
                        HStack {
                            Image(systemName: isAnonymous ? "eye.slash" : "eye")
                                .foregroundColor(DesignColors.ocean)
                            Text("Send anonymously")
                                .foregroundColor(DesignColors.ink)
                        }
                    }
                    .tint(DesignColors.ocean)
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)

                    if let error = localError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    if appState.zipCode.isEmpty {
                        Text("Tip: Set your zip code in Profile to launch from your location")
                            .font(.system(size: 12))
                            .foregroundColor(DesignColors.ink.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    Button(action: launchNote) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "wind")
                                Text("Float Away").font(.custom("Baskerville", size: 18))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(content.isEmpty || isSubmitting ? DesignColors.ocean.opacity(0.5) : DesignColors.ocean)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .disabled(content.isEmpty || isSubmitting)
                }
                .padding()

                if showLaunchAnimation {
                    LaunchAnimation()
                }
            }
            .navigationTitle("Compose")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func launchNote() {
        isSubmitting = true
        localError = nil
        locationManager.requestLocation()
        appState.userLocation = locationManager.location

        Task {
            do {
                let lat = appState.zipCodeLocation?.latitude ?? appState.userLocation?.latitude ?? 39.8283
                let lon = appState.zipCodeLocation?.longitude ?? appState.userLocation?.longitude ?? -98.5795
                let note = try await SupabaseAPI.shared.createNote(
                    content: content,
                    isAnonymous: isAnonymous,
                    lat: lat,
                    lon: lon
                )
                await MainActor.run {
                    isSubmitting = false
                    appState.allNotes.insert(note, at: 0)
                    appState.userNotes.insert(note, at: 0)
                    showLaunchAnimation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showLaunchAnimation = false
                        content = ""
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    localError = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct LaunchAnimation: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var showMessage = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            if !showMessage {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(DesignColors.parchment)
                    .offset(y: offset)
                    .opacity(opacity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "wind")
                        .font(.system(size: 50))
                        .foregroundColor(DesignColors.ocean)
                    Text("Released to the Wind")
                        .font(.custom("Baskerville", size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1)) {
                offset = -300
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showMessage = true }
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var zipCodeInput: String = ""
    @State private var isUpdatingZip = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.parchment.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [DesignColors.ocean, DesignColors.sunset], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // Zip Code Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Location")
                                .font(.custom("Baskerville", size: 18))
                                .foregroundColor(DesignColors.ink)

                            HStack {
                                TextField("Enter ZIP code", text: $zipCodeInput)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(ParchmentFieldStyle())
                                    .frame(width: 120)

                                Button(action: updateZipCode) {
                                    if isUpdatingZip {
                                        ProgressView()
                                    } else {
                                        Text("Set")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                }
                                .frame(width: 60, height: 44)
                                .background(DesignColors.ocean)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .disabled(zipCodeInput.count != 5 || isUpdatingZip)

                                Spacer()
                            }

                            if !appState.zipCode.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("ZIP: \(appState.zipCode)")
                                        .font(.system(size: 14))
                                        .foregroundColor(DesignColors.ink)
                                    Text("(10 mile radius)")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignColors.ink.opacity(0.5))
                                }
                            }

                            Text("Only notes within 10 miles of your ZIP code will be visible to you")
                                .font(.system(size: 12))
                                .foregroundColor(DesignColors.ink.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(16)

                        // Stats
                        HStack(spacing: 40) {
                            StatView(value: "\(appState.sentNotes.count)", label: "Sent")
                            StatView(value: "\(appState.receivedNotes.filter { appState.isNoteOpened($0) }.count)", label: "Received")
                        }
                        .padding()
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(16)

                        Button(action: { appState.signOut() }) {
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                        .padding(.top)

                        Button(action: {
                            appState.clearAllData()
                            zipCodeInput = ""
                        }) {
                            Text("Clear All Data")
                                .font(.system(size: 14))
                                .foregroundColor(DesignColors.ink.opacity(0.5))
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                zipCodeInput = appState.zipCode
            }
        }
    }

    func updateZipCode() {
        guard zipCodeInput.count == 5 else { return }

        isUpdatingZip = true
        appState.zipCode = zipCodeInput

        Task {
            await appState.geocodeZip()
            await appState.loadData()
            await MainActor.run {
                isUpdatingZip = false
            }
        }
    }
}

struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DesignColors.ocean)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignColors.ink.opacity(0.6))
        }
    }
}

#Preview {
    ContentView()
}
