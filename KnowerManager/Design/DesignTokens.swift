import SwiftUI
import Foundation

// MARK: - Design Tokens
struct DesignTokens {
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    struct Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }
    
    // MARK: - Typography
    struct Typography {
        static let caption2 = Font.system(size: 9, weight: .medium)
        static let caption = Font.system(size: 10, weight: .medium)
        static let footnote = Font.system(size: 11, weight: .medium)
        static let callout = Font.system(size: 12, weight: .semibold)
        static let subheadline = Font.system(size: 13, weight: .medium)
        static let body = Font.system(size: 14, weight: .regular)
        static let headline = Font.system(size: 15, weight: .bold)
        static let title3 = Font.system(size: 16, weight: .bold)
        static let title2 = Font.system(size: 18, weight: .bold)
        static let title1 = Font.system(size: 20, weight: .bold)
        static let largeTitle = Font.system(size: 24, weight: .heavy)
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Color.black.opacity(0.08), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.20), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
        static let glow = (color: Color.blue.opacity(0.25), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(0))
    }
    
    // MARK: - Blur & Glass
    static let glassOpacity = 0.8
}

// MARK: - Enhanced Design System
enum DS {
    static let cornerRadius = DesignTokens.Radius.lg
    static let innerPadding = DesignTokens.Spacing.xl
    static let width: CGFloat = 380
    static let heightCollapsed: CGFloat = 780
    static let heightExpanded: CGFloat = 880
    
    // Surfaces
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: DS.cornerRadius)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
    }
    
    static func glassBackground() -> some View {
        RoundedRectangle(cornerRadius: DS.cornerRadius)
            .fill(.ultraThinMaterial)
    }
    
    static let strokeColor = Color(NSColor.separatorColor).opacity(0.4)
    static let subtleStroke = Color.primary.opacity(0.05)
    
    // Gradients
    static let activeGradient = LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let stopGradient = LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let primaryGradient = LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let accentGradient = LinearGradient(colors: [Color.indigo, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let successGradient = LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let warningGradient = LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    
    // Easing
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)
    static let springQuick = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let ease = Animation.easeInOut(duration: 0.2)
    static let easeSlow = Animation.easeInOut(duration: 0.3)
}