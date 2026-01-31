import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var homeZipCode = ""
    @Published var usesLiveLocation = false
    @Published var zipCodeSuggestions: [ZipCode] = []
    @Published var isSaving = false
    @Published var errorMessage: String?

    func loadProfile(from user: User) {
        displayName = user.displayName ?? ""
        homeZipCode = user.homeZipCode ?? ""
        usesLiveLocation = user.usesLiveLocation
    }

    func searchZipCodes(query: String) async {
        guard query.count >= 2 else {
            zipCodeSuggestions = []
            return
        }

        do {
            zipCodeSuggestions = try await SupabaseClient.shared.searchZipCodes(query: query)
        } catch {
            zipCodeSuggestions = []
        }
    }

    func selectZipCode(_ zipCode: ZipCode) {
        homeZipCode = zipCode.zipCode
        zipCodeSuggestions = []
    }

    func saveProfile(authViewModel: AuthViewModel) async {
        isSaving = true
        errorMessage = nil

        await authViewModel.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            homeZipCode: homeZipCode.isEmpty ? nil : homeZipCode,
            usesLiveLocation: usesLiveLocation
        )

        isSaving = false
    }
}
