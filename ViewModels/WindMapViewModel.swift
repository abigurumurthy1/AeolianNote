import Foundation
import CoreLocation
import Combine

@MainActor
final class WindMapViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var currentWindData: WindData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedNote: Note?
    @Published var userCoordinate: CLLocationCoordinate2D?

    private let locationService = LocationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        setupLocationSubscription()
    }

    private func setupLocationSubscription() {
        locationService.$currentLocation
            .compactMap { $0?.coordinate }
            .sink { [weak self] coordinate in
                self?.userCoordinate = coordinate
                Task {
                    await self?.fetchNearbyNotes()
                    await self?.fetchWindData()
                }
            }
            .store(in: &cancellables)
    }

    func startUpdates() {
        locationService.startUpdatingLocation()

        // Refresh notes every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNearbyNotes()
            }
        }
    }

    func stopUpdates() {
        locationService.stopUpdatingLocation()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchNearbyNotes() async {
        guard let coordinate = userCoordinate else { return }

        isLoading = true
        do {
            notes = try await SupabaseClient.shared.fetchActiveNotes(near: coordinate)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchWindData() async {
        guard let coordinate = userCoordinate else { return }

        do {
            currentWindData = try await WeatherService.shared.getWindData(for: coordinate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectNote(_ note: Note) {
        selectedNote = note
    }

    func clearSelection() {
        selectedNote = nil
    }

    func getDistanceToNote(_ note: Note) -> Double? {
        guard let userCoord = userCoordinate else { return nil }
        return LocationService.distance(from: userCoord, to: note.currentCoordinate)
    }
}
