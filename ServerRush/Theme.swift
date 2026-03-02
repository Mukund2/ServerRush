import SwiftUI
import SpriteKit

// MARK: - Theme

enum Theme {

    // MARK: - Colors (SwiftUI)

    static let background       = Color(red: 0.961, green: 0.902, blue: 0.827)  // #F5E6D3
    static let cardBackground   = Color(red: 0.910, green: 0.843, blue: 0.776)  // #E8D7C6
    static let accent           = Color(red: 0.910, green: 0.596, blue: 0.369)  // #E8985E
    static let accentGold       = Color(red: 0.831, green: 0.647, blue: 0.455)  // #D4A574
    static let positive         = Color(red: 0.490, green: 0.718, blue: 0.490)  // #7DB77D
    static let warning          = Color(red: 0.831, green: 0.647, blue: 0.455)  // #D4A574
    static let critical         = Color(red: 0.847, green: 0.357, blue: 0.337)  // #D85B56
    static let textPrimary      = Color(red: 0.239, green: 0.169, blue: 0.122)  // #3D2B1F
    static let textSecondary    = Color(red: 0.545, green: 0.451, blue: 0.333)  // #8B7355
    static let woodTone         = Color(red: 0.627, green: 0.518, blue: 0.361)  // #A0845C

    // MARK: - Colors (SpriteKit / UIKit)

    static let skBackground     = SKColor(red: 0.961, green: 0.902, blue: 0.827, alpha: 1)
    static let skCardBackground = SKColor(red: 0.910, green: 0.843, blue: 0.776, alpha: 1)
    static let skAccent         = SKColor(red: 0.910, green: 0.596, blue: 0.369, alpha: 1)
    static let skAccentGold     = SKColor(red: 0.831, green: 0.647, blue: 0.455, alpha: 1)
    static let skPositive       = SKColor(red: 0.490, green: 0.718, blue: 0.490, alpha: 1)
    static let skWarning        = SKColor(red: 0.831, green: 0.647, blue: 0.455, alpha: 1)
    static let skCritical       = SKColor(red: 0.847, green: 0.357, blue: 0.337, alpha: 1)
    static let skTextPrimary    = SKColor(red: 0.239, green: 0.169, blue: 0.122, alpha: 1)
    static let skTextSecondary  = SKColor(red: 0.545, green: 0.451, blue: 0.333, alpha: 1)
    static let skWoodTone       = SKColor(red: 0.627, green: 0.518, blue: 0.361, alpha: 1)

    // MARK: - Equipment Category Colors (SpriteKit) — Maximalist Palette

    static let skRackColor      = SKColor(red: 0.78, green: 0.42, blue: 0.38, alpha: 1)   // rich terracotta
    static let skCoolingColor   = SKColor(red: 0.38, green: 0.72, blue: 0.78, alpha: 1)   // vivid teal
    static let skPowerColor     = SKColor(red: 0.92, green: 0.72, blue: 0.22, alpha: 1)   // sunflower gold
    static let skNetworkColor   = SKColor(red: 0.62, green: 0.42, blue: 0.72, alpha: 1)   // rich plum

    // MARK: - Fonts (SwiftUI)

    static func headlineFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func moneyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // MARK: - Fonts (UIKit / SpriteKit)

    static func headlineUIFont(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .bold).rounded()
    }

    static func bodyUIFont(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular).rounded()
    }

    static func moneyUIFont(size: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Cozy Palette Additions

    static let grassGreen       = Color(red: 0.486, green: 0.678, blue: 0.384)  // #7CAD62 lush grass
    static let grassDark        = Color(red: 0.380, green: 0.545, blue: 0.298)  // #618B4C darker grass
    static let skyBlue          = Color(red: 0.678, green: 0.835, blue: 0.945)  // #ADD5F1 soft sky
    static let woodBorder       = Color(red: 0.502, green: 0.396, blue: 0.282)  // #806548 dark wood frame
    static let woodLight        = Color(red: 0.725, green: 0.616, blue: 0.482)  // #B99D7B lighter wood

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

// MARK: - UIFont Rounded Helper

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - Wood Panel Modifier (Hay Day-style framed panels)

struct WoodPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.lg
    var borderWidth: CGFloat = 3
    var shadowRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Wood grain background layer
                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .fill(Theme.woodLight)

                    // Inner cream panel
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.background)
                        .padding(borderWidth)

                    // Subtle wood grain overlay (horizontal lines)
                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                        .fill(.clear)
                        .overlay(
                            WoodGrainOverlay(cornerRadius: cornerRadius + 2)
                                .opacity(0.06)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous))
                }
                .shadow(color: Theme.woodBorder.opacity(0.3), radius: shadowRadius, y: 4)
            )
    }
}

/// Subtle horizontal wood grain lines drawn via Canvas
struct WoodGrainOverlay: View {
    var cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 5
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    // Slightly wavy line
                    let midX = size.width / 2
                    let wave = CGFloat.random(in: -0.5...0.5)
                    p.addQuadCurve(to: CGPoint(x: size.width, y: y + wave),
                                   control: CGPoint(x: midX, y: y + CGFloat.random(in: -1...1)))
                }
                context.stroke(path, with: .color(Theme.woodBorder), lineWidth: 0.5)
                y += spacing
            }
        }
    }
}

extension View {
    /// Applies Hay Day-style wood panel framing to a view
    func woodPanel(cornerRadius: CGFloat = Theme.Radius.lg, borderWidth: CGFloat = 3, shadowRadius: CGFloat = 8) -> some View {
        modifier(WoodPanelModifier(cornerRadius: cornerRadius, borderWidth: borderWidth, shadowRadius: shadowRadius))
    }
}

// MARK: - Cozy Button Style

struct CozyButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .background(
                ZStack {
                    // Bottom shadow layer (darker)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color.opacity(0.7))
                        .offset(y: configuration.isPressed ? 1 : 3)

                    // Main button face
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color)
                        .offset(y: configuration.isPressed ? 1 : 0)

                    // Top highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .offset(y: configuration.isPressed ? 1 : 0)
                }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
