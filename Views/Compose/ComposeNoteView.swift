import SwiftUI

struct ComposeNoteView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ComposeViewModel()
    @State private var showingLaunchAnimation = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.parchment
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Paper texture area
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // Character count
                        HStack {
                            Spacer()
                            Text("\(viewModel.remainingCharacters)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(
                                    viewModel.remainingCharacters < 20
                                    ? .red
                                    : DesignSystem.Colors.ink.opacity(0.5)
                                )
                        }

                        // Text input
                        TextEditor(text: $viewModel.content)
                            .font(DesignSystem.Fonts.handwritten(size: 20))
                            .foregroundColor(DesignSystem.Colors.ink)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 150)
                            .onChange(of: viewModel.content) { newValue in
                                if newValue.count > viewModel.characterLimit {
                                    viewModel.content = String(newValue.prefix(viewModel.characterLimit))
                                }
                            }

                        // Placeholder
                        if viewModel.content.isEmpty {
                            Text("Write your message to the wind...")
                                .font(DesignSystem.Fonts.handwritten(size: 20))
                                .foregroundColor(DesignSystem.Colors.ink.opacity(0.3))
                                .allowsHitTesting(false)
                                .padding(.top, -140)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.parchment)
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.Colors.parchmentDark, lineWidth: 1)
                    )

                    // Options
                    Toggle(isOn: $viewModel.isAnonymous) {
                        HStack {
                            Image(systemName: viewModel.isAnonymous ? "eye.slash" : "eye")
                                .foregroundColor(DesignSystem.Colors.ocean)
                            Text("Send anonymously")
                                .font(DesignSystem.Fonts.body())
                                .foregroundColor(DesignSystem.Colors.ink)
                        }
                    }
                    .tint(DesignSystem.Colors.ocean)
                    .padding()
                    .background(DesignSystem.Colors.parchment.opacity(0.8))
                    .cornerRadius(12)

                    Spacer()

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Launch button
                    Button(action: launchNote) {
                        HStack {
                            if viewModel.isLaunching {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wind")
                                Text("Float Away")
                                    .font(DesignSystem.Fonts.elegant(size: 18))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        viewModel.isValid
                        ? DesignSystem.Colors.ocean
                        : DesignSystem.Colors.ocean.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .disabled(!viewModel.isValid || viewModel.isLaunching)
                }
                .padding()

                // Launch animation overlay
                if showingLaunchAnimation {
                    LaunchingAnimationView {
                        showingLaunchAnimation = false
                        viewModel.reset()
                    }
                }
            }
            .navigationTitle("Compose")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func launchNote() {
        guard let userId = authViewModel.currentUser?.id else { return }

        Task {
            await viewModel.launchNote(userId: userId)
            if viewModel.launchComplete {
                showingLaunchAnimation = true
            }
        }
    }
}

#Preview {
    ComposeNoteView()
        .environmentObject(AuthViewModel())
}
