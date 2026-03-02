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

    // MARK: - Equipment Category Colors (SpriteKit)

    static let skRackColor      = SKColor(red: 0.65, green: 0.68, blue: 0.62, alpha: 1)   // warm gray
    static let skCoolingColor   = SKColor(red: 0.68, green: 0.80, blue: 0.88, alpha: 1)   // soft pastel blue
    static let skPowerColor     = SKColor(red: 0.88, green: 0.75, blue: 0.45, alpha: 1)   // warm amber
    static let skNetworkColor   = SKColor(red: 0.75, green: 0.65, blue: 0.85, alpha: 1)   // soft lavender

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
