import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        guard let userId = await SupabaseClient.shared.getCurrentSession() else {
            isAuthenticated = false
            return
        }

        do {
            currentUser = try await SupabaseClient.shared.fetchUser(id: userId)
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signUp(email: String, password: String, displayName: String?) async {
        isLoading = true
        errorMessage = nil

        do {
            var user = try await SupabaseClient.shared.signUp(email: email, password: password)
            if let displayName = displayName {
                user.displayName = displayName
                try await SupabaseClient.shared.updateUser(user)
            }
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            currentUser = try await SupabaseClient.shared.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        do {
            try await SupabaseClient.shared.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(displayName: String?, homeZipCode: String?, usesLiveLocation: Bool) async {
        guard var user = currentUser else { return }

        user.displayName = displayName
        user.homeZipCode = homeZipCode
        user.usesLiveLocation = usesLiveLocation

        do {
            try await SupabaseClient.shared.updateUser(user)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
