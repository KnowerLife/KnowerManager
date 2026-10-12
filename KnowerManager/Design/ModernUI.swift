import SwiftUI

struct ModernSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 20, height: 20)
                    .background(color.opacity(0.12), in: Circle())
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(1.6)
                Spacer()
            }
            content
        }
    }
}

struct ModernCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content
    
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(padding)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppThemeTokens.Surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppThemeTokens.Border.subtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
