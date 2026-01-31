import SwiftUI

struct DesignSystem {
    struct Colors {
        static let primary = Color("Primary", bundle: nil)
        static let parchment = Color(red: 0.96, green: 0.93, blue: 0.87)
        static let parchmentDark = Color(red: 0.88, green: 0.82, blue: 0.72)
        static let ink = Color(red: 0.2, green: 0.15, blue: 0.1)
        static let wind = Color(red: 0.6, green: 0.75, blue: 0.85)
        static let glow = Color(red: 1.0, green: 0.9, blue: 0.6)
        static let sunset = Color(red: 0.95, green: 0.6, blue: 0.4)
        static let ocean = Color(red: 0.3, green: 0.5, blue: 0.7)
    }

    struct Fonts {
        static func handwritten(size: CGFloat) -> Font {
            .custom("Bradley Hand", size: size)
        }

        static func elegant(size: CGFloat) -> Font {
            .custom("Baskerville", size: size)
        }

        static func body(size: CGFloat = 16) -> Font {
            .system(size: size, weight: .regular, design: .serif)
        }
    }

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}

// MARK: - Parchment Background Modifier

struct ParchmentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    DesignSystem.Colors.parchment
                    // Texture overlay
                    Image(systemName: "")
                        .opacity(0.05)
                }
            )
    }
}

extension View {
    func parchmentBackground() -> some View {
        modifier(ParchmentBackground())
    }
}

// MARK: - Glowing Note Style

struct GlowingNoteStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? DesignSystem.Colors.glow.opacity(0.8) : .clear, radius: 10)
            .shadow(color: isActive ? DesignSystem.Colors.glow.opacity(0.4) : .clear, radius: 20)
    }
}

extension View {
    func glowingNote(isActive: Bool = true) -> some View {
        modifier(GlowingNoteStyle(isActive: isActive))
    }
}
