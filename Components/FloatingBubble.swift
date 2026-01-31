import SwiftUI

struct FloatingBubble: View {
    let note: Note
    let onTap: () -> Void

    @State private var floatOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Bubble
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.glow.opacity(0.9),
                                DesignSystem.Colors.sunset.opacity(0.7)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .glowingNote()

                // Content preview
                VStack(spacing: 4) {
                    if !note.isAnonymous, let name = note.senderDisplayName {
                        Text(name.prefix(1))
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundColor(DesignSystem.Colors.ink)
                    } else {
                        Image(systemName: "questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(DesignSystem.Colors.ink.opacity(0.7))
                    }

                    // Distance
                    if let distance = note.distanceFromUser {
                        Text(String(format: "%.1f mi", distance))
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
                    }
                }
            }
            .offset(y: floatOffset)
            .rotationEffect(.degrees(rotationAngle))
        }
        .buttonStyle(.plain)
        .onAppear {
            startFloating()
        }
    }

    private func startFloating() {
        let randomDelay = Double.random(in: 0...1)
        let randomDuration = Double.random(in: 2...3)

        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
            withAnimation(.easeInOut(duration: randomDuration).repeatForever(autoreverses: true)) {
                floatOffset = CGFloat.random(in: -10...10)
                rotationAngle = Double.random(in: -5...5)
            }
        }
    }
}

struct FloatingBubbleRow: View {
    let note: Note
    let timeRemaining: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Avatar bubble
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.glow, DesignSystem.Colors.sunset],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .glowingNote()

                    if !note.isAnonymous, let name = note.senderDisplayName {
                        Text(name.prefix(1).uppercased())
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(DesignSystem.Colors.ink)
                    } else {
                        Image(systemName: "questionmark")
                            .foregroundColor(DesignSystem.Colors.ink.opacity(0.7))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !note.isAnonymous, let name = note.senderDisplayName {
                        Text(name)
                            .font(DesignSystem.Fonts.elegant(size: 16))
                            .foregroundColor(DesignSystem.Colors.ink)
                    } else {
                        Text("Anonymous")
                            .font(DesignSystem.Fonts.elegant(size: 16))
                            .foregroundColor(DesignSystem.Colors.ink.opacity(0.7))
                            .italic()
                    }

                    HStack {
                        Image(systemName: "wind")
                            .font(.system(size: 12))
                        Text(String(format: "%.0f miles traveled", note.totalDistance))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(DesignSystem.Colors.ink.opacity(0.5))
                }

                Spacer()

                // Time remaining
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeRemaining)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.sunset)

                    Text("remaining")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.ink.opacity(0.4))
                }
            }
            .padding()
            .background(DesignSystem.Colors.parchment)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        FloatingBubble(
            note: Note.create(
                content: "Test",
                isAnonymous: false,
                senderId: UUID(),
                coordinate: .init(latitude: 0, longitude: 0)
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
