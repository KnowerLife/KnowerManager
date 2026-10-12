import SwiftUI

// MARK: - Unified Design Kit Export
// This file provides convenient access to all design components
// and is meant for quick reference/editing

struct DesignKit {
    static let tokens = DesignTokens.self
    static let ds = DS.self
    static let ui = UXUIKit.self
}

// MARK: - Quick Access Helpers
extension View {
    func modernCard() -> some View {
        self.modifier(ModernCardModifier())
    }
    
    func elevated() -> some View {
        self.shadow(color: DesignTokens.Shadow.small.color, radius: DesignTokens.Shadow.small.radius, x: DesignTokens.Shadow.small.x, y: DesignTokens.Shadow.small.y)
    }
    
    func glassEffect() -> some View {
        self.background(.ultraThinMaterial)
    }
}

// MARK: - Modifiers
struct ModernCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(DS.glassBackground())
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .cornerRadius(DS.cornerRadius)
            .shadow(color: DesignTokens.Shadow.small.color, radius: DesignTokens.Shadow.small.radius, x: DesignTokens.Shadow.small.x, y: DesignTokens.Shadow.small.y)
    }
}
