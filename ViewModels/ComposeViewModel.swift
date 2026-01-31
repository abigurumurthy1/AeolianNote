import Foundation
import CoreLocation

@MainActor
final class ComposeViewModel: ObservableObject {
    @Published var content = ""
    @Published var isAnonymous = false
    @Published var isLaunching = false
    @Published var launchComplete = false
    @Published var errorMessage: String?

    let characterLimit = 140

    var remainingCharacters: Int {
        characterLimit - content.count
    }

    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count <= characterLimit
    }

    func launchNote(userId: UUID) async {
        guard isValid else { return }

        isLaunching = true
        errorMessage = nil

        do {
            // Get user's current location
            let location = try await LocationService.shared.getCurrentLocation()

            // Moderate content
            let moderationResult = try await ModerationService.shared.moderate(content: content)
            if moderationResult.flagged {
                errorMessage = "Your note contains content that violates our guidelines."
                isLaunching = false
                return
            }

            // Create the note
            let note = Note.create(
                content: content,
                isAnonymous: isAnonymous,
                senderId: userId,
                coordinate: location.coordinate
            )

            _ = try await SupabaseClient.shared.createNote(note)

            // Success
            launchComplete = true
            content = ""
            isAnonymous = false

            // Haptic feedback
            HapticService.shared.playLaunch()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLaunching = false
    }

    func reset() {
        content = ""
        isAnonymous = false
        launchComplete = false
        errorMessage = nil
    }
}
