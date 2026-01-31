import SwiftUI

struct NoteRevealView: View {
    let note: Note
    let onCatch: () -> Void
    let onDismiss: () -> Void

    @State private var revealProgress: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var countdownSeconds: Int = 10
    @State private var isDissolved = false
    @State private var showJourney = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Countdown
                if !isDissolved {
                    Text("\(countdownSeconds)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(countdownSeconds <= 3 ? .red : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }

                // The note
                ZStack {
                    // Paper envelope opening animation
                    EnvelopeView(openProgress: revealProgress)

                    // Content (revealed after envelope opens)
                    if revealProgress >= 1 {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            // Sender info
                            if !note.isAnonymous, let name = note.senderDisplayName {
                                HStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.ocean)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(name.prefix(1).uppercased())
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        )

                                    Text("From \(name)")
                                        .font(DesignSystem.Fonts.elegant(size: 14))
                                        .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))

                                    Spacer()
                                }
                            }

                            // Message content
                            Text(note.content)
                                .font(DesignSystem.Fonts.handwritten(size: 24))
                                .foregroundColor(DesignSystem.Colors.ink)
                                .multilineTextAlignment(.center)
                                .padding()

                            // Journey stats
                            Button(action: { showJourney.toggle() }) {
                                HStack {
                                    Image(systemName: "map")
                                    Text(String(format: "%.1f miles traveled", note.totalDistance))
                                }
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.ocean)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .opacity(contentOpacity)
                    }
                }
                .frame(width: 300, height: 350)

                // Catch button
                if !isDissolved && revealProgress >= 1 {
                    Button(action: {
                        HapticService.shared.playCatch()
                        onCatch()
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Catch This Note")
                        }
                        .font(DesignSystem.Fonts.elegant(size: 18))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.ocean)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .opacity(contentOpacity)
                }

                // Dissolved message
                if isDissolved {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "wind")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))

                        Text("The note dissolved into the wind...")
                            .font(DesignSystem.Fonts.elegant(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear {
            startRevealAnimation()
        }
        .onReceive(timer) { _ in
            if countdownSeconds > 0 && !isDissolved {
                countdownSeconds -= 1
            } else if countdownSeconds == 0 && !isDissolved {
                dissolveNote()
            }
        }
        .onTapGesture {
            if isDissolved {
                onDismiss()
            }
        }
        .sheet(isPresented: $showJourney) {
            JourneyMapSheet(note: note)
        }
    }

    private func startRevealAnimation() {
        HapticService.shared.playUnfold()

        // Open envelope
        withAnimation(.easeOut(duration: 1.0)) {
            revealProgress = 1
        }

        // Fade in content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }

    private func dissolveNote() {
        withAnimation(.easeOut(duration: 0.5)) {
            isDissolved = true
        }

        // Auto dismiss after showing dissolved message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onDismiss()
        }
    }
}

struct EnvelopeView: View {
    let openProgress: CGFloat

    var body: some View {
        ZStack {
            // Back of envelope
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.parchmentDark)

            // Main envelope body
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.parchment)
                .scaleEffect(y: 1 - openProgress * 0.1, anchor: .bottom)

            // Top flap (opens)
            Triangle()
                .fill(DesignSystem.Colors.parchmentDark)
                .frame(height: 100)
                .rotationEffect(.degrees(openProgress * -180), anchor: .top)
                .offset(y: -125)
                .opacity(1 - openProgress)

            // Seal
            Circle()
                .fill(DesignSystem.Colors.sunset)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "wind")
                        .foregroundColor(.white)
                )
                .offset(y: -80)
                .scaleEffect(1 - openProgress)
                .opacity(1 - openProgress)
        }
    }
}

struct JourneyMapSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                JourneyPathView(journeyPath: note.journeyPath)
                    .padding()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Journey Details")
                        .font(DesignSystem.Fonts.elegant(size: 20))

                    Text("Started: \(note.createdAt.formatted())")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("Distance: \(String(format: "%.1f miles", note.totalDistance))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("Waypoints: \(note.journeyPath.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Spacer()
            }
            .navigationTitle("Note's Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NoteRevealView(
        note: Note.create(
            content: "Hello from across the wind! 🌬️",
            isAnonymous: false,
            senderId: UUID(),
            coordinate: .init(latitude: 40.7128, longitude: -74.0060)
        ),
        onCatch: {},
        onDismiss: {}
    )
}
