import SwiftUI

struct InboxView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = InboxViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.parchment
                    .ignoresSafeArea()

                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    EmptyInboxView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(viewModel.notes) { note in
                                FloatingBubbleRow(
                                    note: note,
                                    timeRemaining: viewModel.formatTimeRemaining(note),
                                    onTap: { viewModel.openNote(note) }
                                )
                            }
                        }
                        .padding()
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await viewModel.fetchInbox(userId: userId)
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        await viewModel.fetchInbox(userId: userId)
                    }
                    viewModel.subscribeToEncounters(userId: userId)
                }
            }
            .onDisappear {
                viewModel.unsubscribe()
            }
            .fullScreenCover(isPresented: $viewModel.isRevealingNote) {
                if let note = viewModel.selectedNote,
                   let userId = authViewModel.currentUser?.id {
                    NoteRevealView(
                        note: note,
                        onCatch: {
                            Task {
                                await viewModel.catchNote(userId: userId)
                            }
                        },
                        onDismiss: {
                            viewModel.dismissNote()
                        }
                    )
                }
            }
        }
    }
}

struct EmptyInboxView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "wind")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.ink.opacity(0.3))

            Text("No notes yet")
                .font(DesignSystem.Fonts.elegant(size: 24))
                .foregroundColor(DesignSystem.Colors.ink)

            Text("Notes will appear here when the wind\ncarries them to your location")
                .font(DesignSystem.Fonts.body(size: 14))
                .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    InboxView()
        .environmentObject(AuthViewModel())
}
