import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var locationService: LocationService

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.parchment
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Avatar
                        AvatarView(
                            name: viewModel.displayName,
                            avatarUrl: authViewModel.currentUser?.avatarUrl
                        )
                        .padding(.top, DesignSystem.Spacing.lg)

                        // Stats
                        if let stats = authViewModel.currentUser?.stats {
                            StatsCardView(stats: stats)
                        }

                        // Profile form
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Profile Settings")
                                .font(DesignSystem.Fonts.elegant(size: 18))
                                .foregroundColor(DesignSystem.Colors.ink)

                            // Display name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Display Name")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))

                                TextField("Your name", text: $viewModel.displayName)
                                    .textFieldStyle(ParchmentTextFieldStyle())
                            }

                            // Home ZIP code
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Home ZIP Code")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))

                                TextField("ZIP Code", text: $viewModel.homeZipCode)
                                    .textFieldStyle(ParchmentTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: viewModel.homeZipCode) { query in
                                        Task {
                                            await viewModel.searchZipCodes(query: query)
                                        }
                                    }

                                // ZIP code suggestions
                                if !viewModel.zipCodeSuggestions.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.zipCodeSuggestions) { zipCode in
                                            Button(action: {
                                                viewModel.selectZipCode(zipCode)
                                            }) {
                                                HStack {
                                                    Text(zipCode.displayName)
                                                        .font(.system(size: 14))
                                                    Spacer()
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                            }
                                            .buttonStyle(.plain)

                                            Divider()
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                }
                            }

                            // Live location toggle
                            Toggle(isOn: $viewModel.usesLiveLocation) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Live Location")
                                        .font(DesignSystem.Fonts.body())
                                        .foregroundColor(DesignSystem.Colors.ink)

                                    Text("Allow notes to find you anywhere")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.Colors.ink.opacity(0.5))
                                }
                            }
                            .tint(DesignSystem.Colors.ocean)
                            .onChange(of: viewModel.usesLiveLocation) { enabled in
                                if enabled {
                                    locationService.requestPermission()
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(16)

                        // Save button
                        Button(action: saveProfile) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(DesignSystem.Fonts.elegant(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignSystem.Colors.ocean)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(viewModel.isSaving)

                        // Sign out button
                        Button(action: signOut) {
                            Text("Sign Out")
                                .font(DesignSystem.Fonts.body())
                                .foregroundColor(.red)
                        }
                        .padding(.top, DesignSystem.Spacing.md)

                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let user = authViewModel.currentUser {
                    viewModel.loadProfile(from: user)
                }
            }
        }
    }

    private func saveProfile() {
        Task {
            await viewModel.saveProfile(authViewModel: authViewModel)
        }
    }

    private func signOut() {
        Task {
            await authViewModel.signOut()
        }
    }
}

struct AvatarView: View {
    let name: String
    let avatarUrl: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.ocean, DesignSystem.Colors.sunset],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)

            if let url = avatarUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialText
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                initialText
            }
        }
    }

    private var initialText: some View {
        Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
            .font(.system(size: 40, weight: .semibold, design: .serif))
            .foregroundColor(.white)
    }
}

struct StatsCardView: View {
    let stats: User.UserStats

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Your Journey")
                .font(DesignSystem.Fonts.elegant(size: 18))
                .foregroundColor(DesignSystem.Colors.ink)

            HStack(spacing: DesignSystem.Spacing.lg) {
                StatItem(value: "\(stats.notesLaunched)", label: "Launched")
                StatItem(value: "\(stats.notesCaught)", label: "Caught")
                StatItem(value: String(format: "%.0f", stats.totalMilesTraveled), label: "Miles")
            }
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(16)
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.ocean)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocationService.shared)
}
