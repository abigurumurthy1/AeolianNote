import Foundation
import Supabase

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedNote: Note?
    @Published var isRevealingNote = false

    private var realtimeChannel: RealtimeChannelV2?

    func fetchInbox(userId: UUID) async {
        isLoading = true
        do {
            notes = try await SupabaseClient.shared.fetchInboxNotes(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func subscribeToEncounters(userId: UUID) {
        realtimeChannel = SupabaseClient.shared.subscribeToNoteEncounters(userId: userId) { [weak self] encounter in
            Task { @MainActor in
                await self?.fetchInbox(userId: userId)
                HapticService.shared.playNotification()
            }
        }
    }

    func unsubscribe() {
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }

    func openNote(_ note: Note) {
        selectedNote = note
        isRevealingNote = true
    }

    func catchNote(userId: UUID) async {
        guard let note = selectedNote else { return }

        do {
            try await SupabaseClient.shared.catchNote(noteId: note.id, userId: userId)

            // Remove from inbox
            notes.removeAll { $0.id == note.id }

            // Update the selected note status
            if var updatedNote = selectedNote {
                updatedNote.status = .caught
                selectedNote = updatedNote
            }

            HapticService.shared.playCatch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissNote() {
        selectedNote = nil
        isRevealingNote = false
    }

    func formatTimeRemaining(_ note: Note) -> String {
        let remaining = note.timeRemaining
        if remaining <= 0 {
            return "Expired"
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
