import SwiftUI

struct CompassNeedle: View {
    let windBearing: Double
    @State private var wobble: Double = 0

    var body: some View {
        ZStack {
            // Compass circle
            Circle()
                .stroke(DesignSystem.Colors.parchmentDark, lineWidth: 2)
                .frame(width: 60, height: 60)

            // Cardinal directions
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
                    .offset(y: -22)
                    .rotationEffect(.degrees(cardinalAngle(for: direction)))
            }

            // Needle
            VStack(spacing: 0) {
                Triangle()
                    .fill(DesignSystem.Colors.sunset)
                    .frame(width: 8, height: 20)

                Rectangle()
                    .fill(DesignSystem.Colors.ink.opacity(0.3))
                    .frame(width: 2, height: 10)
            }
            .rotationEffect(.degrees(windBearing + wobble))
            .animation(.easeInOut(duration: 0.5), value: windBearing)

            // Center dot
            Circle()
                .fill(DesignSystem.Colors.ink)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            startWobble()
        }
    }

    private func cardinalAngle(for direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func startWobble() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            wobble = Double.random(in: -3...3)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CompassNeedle(windBearing: 45)
        .padding()
        .background(DesignSystem.Colors.parchment)
}
