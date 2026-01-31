import SwiftUI

struct LaunchingAnimationView: View {
    let onComplete: () -> Void

    @State private var noteScale: CGFloat = 1.0
    @State private var noteOpacity: Double = 1.0
    @State private var noteOffset: CGFloat = 0
    @State private var noteRotation: Double = 0
    @State private var particles: [Particle] = []
    @State private var showSuccessMessage = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }

            // The note being launched
            if !showSuccessMessage {
                NoteShape()
                    .fill(DesignSystem.Colors.parchment)
                    .frame(width: 100, height: 80)
                    .shadow(color: DesignSystem.Colors.glow, radius: 10)
                    .scaleEffect(noteScale)
                    .opacity(noteOpacity)
                    .offset(y: noteOffset)
                    .rotationEffect(.degrees(noteRotation))
            }

            // Success message
            if showSuccessMessage {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "wind")
                        .font(.system(size: 50))
                        .foregroundColor(DesignSystem.Colors.ocean)

                    Text("Released to the Wind")
                        .font(DesignSystem.Fonts.elegant(size: 24))
                        .foregroundColor(.white)

                    Text("Your note is now drifting across the sky")
                        .font(DesignSystem.Fonts.body(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Create particles
        for i in 0..<20 {
            let particle = Particle(
                id: i,
                x: CGFloat.random(in: -20...20),
                y: CGFloat.random(in: -20...20),
                size: CGFloat.random(in: 4...12),
                color: [DesignSystem.Colors.glow, DesignSystem.Colors.sunset, DesignSystem.Colors.wind].randomElement()!,
                opacity: 0
            )
            particles.append(particle)
        }

        // Animate note folding and rising
        withAnimation(.easeIn(duration: 0.3)) {
            noteScale = 0.8
        }

        // Particle burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for i in particles.indices {
                withAnimation(.easeOut(duration: 0.8)) {
                    particles[i].x = CGFloat.random(in: -150...150)
                    particles[i].y = CGFloat.random(in: -200...-50)
                    particles[i].opacity = 1
                }
            }
        }

        // Note rises and fades
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            noteOffset = -300
            noteRotation = Double.random(in: -30...30)
            noteScale = 0.5
            noteOpacity = 0
        }

        // Particles fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            for i in particles.indices {
                withAnimation(.easeOut(duration: 0.5)) {
                    particles[i].opacity = 0
                }
            }
        }

        // Show success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring()) {
                showSuccessMessage = true
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onComplete()
        }
    }
}

struct Particle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}

struct NoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Folded paper shape
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        // Fold line
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 5))

        return path
    }
}

#Preview {
    LaunchingAnimationView(onComplete: {})
}
