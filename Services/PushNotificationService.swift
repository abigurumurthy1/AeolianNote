import Foundation

actor PushNotificationService {
    static let shared = PushNotificationService()

    private var currentToken: String?

    private init() {}

    func updatePushToken(_ token: String) async {
        currentToken = token

        // Update in Supabase if user is authenticated
        guard let userId = await SupabaseClient.shared.getCurrentSession() else { return }

        do {
            try await SupabaseClient.shared.updatePushToken(userId: userId, token: token)
        } catch {
            print("Failed to update push token: \(error)")
        }
    }

    func getCurrentToken() -> String? {
        currentToken
    }
}
