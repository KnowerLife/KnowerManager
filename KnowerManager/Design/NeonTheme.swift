import SwiftUI

// MARK: - Modern Theme
struct AppThemeTokens {
    
    // MARK: - Colors
    struct Surface {
        static let background = Color(NSColor.windowBackgroundColor)
        static let elevated = Color(NSColor.controlBackgroundColor).opacity(0.95)
        static let overlay = Color.black.opacity(0.03)
        static let glass = Color(NSColor.windowBackgroundColor).opacity(0.92)
    }
    
    struct Border {
        static let subtle = Color(NSColor.separatorColor).opacity(0.25)
        static let normal = Color(NSColor.separatorColor).opacity(0.4)
        static let focus = Color.blue.opacity(0.6)
    }
    
    struct Status {
        static let success = Color(hex: "#22C55E")
        static let successBG = Color(hex: "#22C55E").opacity(0.12)
        static let warning = Color(hex: "#F59E0B")
        static let warningBG = Color(hex: "#F59E0B").opacity(0.12)
        static let danger = Color(hex: "#EF4444")
        static let dangerBG = Color(hex: "#EF4444").opacity(0.12)
        static let info = Color(hex: "#3B82F6")
        static let infoBG = Color(hex: "#3B82F6").opacity(0.12)
        static let neutral = Color(NSColor.secondaryLabelColor)
    }
    
    struct Accent {
        static let primary = LinearGradient(colors: [Color(hex: "#4D7CFE"), Color(hex: "#6F3DF5")], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let success = LinearGradient(colors: [Color(hex: "#10B981"), Color(hex: "#34D399")], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let danger = LinearGradient(colors: [Color(hex: "#EF4444"), Color(hex: "#FB7185")], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let warning = LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#FBBF24")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - Spacing
    static let paddingXS: CGFloat = 4
    static let paddingSM: CGFloat = 8
    static let paddingMD: CGFloat = 12
    static let paddingLG: CGFloat = 16
    static let paddingXL: CGFloat = 20
    static let padding2XL: CGFloat = 24
    
    // MARK: - Radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 14
    static let radiusXL: CGFloat = 18
    static let radius2XL: CGFloat = 24
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}