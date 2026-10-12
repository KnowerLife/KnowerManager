import SwiftUI

// MARK: - Button Styles
struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let variant: ButtonVariant
    
    enum ButtonVariant {
        case filled, ghost, outline
    }
    
    init(color: Color = .blue, variant: ButtonVariant = .filled) {
        self.color = color
        self.variant = variant
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.footnote.weight(.semibold))
            .padding(.vertical, DesignTokens.Spacing.sm + 1)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if variant == .filled {
                        (configuration.isPressed ? color.opacity(0.85) : color)
                    } else {
                        Color.clear
                    }
                }
            )
            .foregroundColor(variant == .filled ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(variant == .outline ? color.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(DesignTokens.Radius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(DS.ease, value: configuration.isPressed)
            .shadow(color: variant == .filled ? color.opacity(0.25) : .clear, radius: 4, x: 0, y: 2)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DS.springQuick, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
            )
            .cornerRadius(DesignTokens.Radius.sm)
            .animation(DS.ease, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.footnote)
            .foregroundColor(.secondary)
            .padding(DesignTokens.Spacing.sm)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.10) : Color.primary.opacity(0.06))
            )
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(DS.ease, value: configuration.isPressed)
    }
}

// MARK: - Cards
struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(DS.glassBackground())
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .cornerRadius(DS.cornerRadius)
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
    }
}

struct ElevatedCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: DesignTokens.Shadow.small.color, radius: DesignTokens.Shadow.small.radius, x: DesignTokens.Shadow.small.x, y: DesignTokens.Shadow.small.y)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .stroke(DS.subtleStroke, lineWidth: 1)
            )
            .cornerRadius(DS.cornerRadius)
    }
}

// MARK: - Inputs
struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    
    init(_ placeholder: String, text: Binding<String>, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundColor(.secondary)
            }
            TextField(placeholder, text: $text)
                .font(DesignTokens.Typography.footnote)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(DS.strokeColor, lineWidth: 1)
        )
    }
}

// MARK: - Tags/Chips
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .padding(.horizontal, DesignTokens.Spacing.sm + 2)
                .padding(.vertical, DesignTokens.Spacing.xs + 2)
                .foregroundColor(selected ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                        .fill(selected ? Color.blue : Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                        .stroke(selected ? Color.blue.opacity(0.5) : DS.strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Badges
struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption2.weight(.bold))
            .padding(.horizontal, DesignTokens.Spacing.xs + 2)
            .padding(.vertical, 2)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                    .fill(color)
            )
    }
}

// MARK: - Section Header
struct SectionHeaderDS: View {
    let title: String
    let accessory: AnyView?
    
    init(_ title: String, accessory: AnyView? = nil) {
        self.title = title
        self.accessory = accessory
    }
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DesignTokens.Typography.caption2.weight(.heavy))
                .tracking(0.8)
                .foregroundColor(.secondary)
            Spacer()
            if let accessory = accessory {
                accessory
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
    }
}