import SwiftUI

struct Theme {
    static let background = Color(hex: "0D0D0D") // Almost black
    static let surface = Color(hex: "1C1C1E")    // Dark grey card
    static let accent = Color(hex: "CCFF00")      // Neon Lime
    static let secondaryAccent = Color(hex: "00E0FF") // Electric Blue
    
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    
    struct Fonts {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        
        static func headline(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        
        static func body(_ size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        
        static func number(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }
    }
    
    struct Layout {
        static let cornerRadius: CGFloat = 20
        static let padding: CGFloat = 20
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func premiumCard() -> some View {
        self.modifier(PremiumCardModifier())
    }
    
    func appBackground() -> some View {
        self.background(Theme.background)
    }
}
