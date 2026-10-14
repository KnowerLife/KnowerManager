import SwiftUI

// MARK: - UX/UI Kit (Single Source for Editing)
struct UXUIKit {
    
    // MARK: - Navigation & Tabs
    struct ModernTabBar: View {
        @Binding var selectedTab: Int
        let tabs: [TabItem]
        var namespace: Namespace.ID
        
        struct TabItem {
            let title: String
            let icon: String
            let badge: Int?
        }
        
        var body: some View {
            HStack(spacing: DesignTokens.Spacing.xs + 1) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    tabButton(tab: tab, tag: index)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .cornerRadius(DesignTokens.Radius.md)
        }
        
        @ViewBuilder
        private func tabButton(tab: TabItem, tag: Int) -> some View {
            Button(action: {
                withAnimation(DS.spring) {
                    selectedTab = tag
                }
            }) {
                HStack(spacing: DesignTokens.Spacing.xs + 2) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: tab.icon)
                            .font(DesignTokens.Typography.callout.weight(.bold))
                        if let badge = tab.badge, badge > 0 {
                            Badge(text: "\(badge)", color: .red)
                                .offset(x: 4, y: -4)
                        }
                    }
                    if selectedTab == tag {
                        Text(tab.title)
                            .font(DesignTokens.Typography.footnote.weight(.bold))
                            .lineLimit(1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundColor(selectedTab == tag ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    ZStack {
                        if selectedTab == tag {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2)
                                .fill(DS.primaryGradient)
                                .matchedGeometryEffect(id: "TAB_BG", in: namespace)
                                .shadow(color: Color.blue.opacity(0.25), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(2))
                        } else {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2)
                                .fill(Color.clear)
                        }
                    }
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Cards & Panels
    struct FeatureCard: View {
        let title: String
        let subtitle: String?
        let icon: String
        let color: Color
        @Binding var isEnabled: Bool
        let action: (() -> Void)?
        
        init(title: String, subtitle: String? = nil, icon: String, color: Color, isEnabled: Binding<Bool>, action: (() -> Void)? = nil) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.color = color
            self._isEnabled = isEnabled
            self.action = action
        }
        
        var body: some View {
            Button(action: {
                withAnimation(DS.springQuick) {
                    isEnabled.toggle()
                }
                action?()
            }) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(isEnabled ? color : Color.primary.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(DesignTokens.Typography.headline.weight(.semibold))
                            .foregroundColor(isEnabled ? .white : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(DesignTokens.Typography.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: color))
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: DesignTokens.Shadow.small.color, radius: DesignTokens.Shadow.small.radius, x: DesignTokens.Shadow.small.x, y: DesignTokens.Shadow.small.y)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .stroke(isEnabled ? color.opacity(0.25) : DS.subtleStroke, lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Status Header
    struct StatusHeader: View {
        let isRunning: Bool
        let isChecking: Bool
        let title: String
        let subtitle: String
        let action: () -> Void
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                    .fill(
                        isRunning
                        ? Color.green.opacity(0.10)
                        : Color.primary.opacity(0.05)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                            .stroke(isRunning ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1)
                    )
                HStack(spacing: DesignTokens.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(spacing: DesignTokens.Spacing.xs + 2) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: statusColor.opacity(0.5), radius: 2)
                            Text(title)
                                .font(DesignTokens.Typography.callout.weight(.bold))
                                .foregroundColor(isRunning ? .green : .primary)
                        }
                        Text(subtitle)
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: action) {
                        ZStack {
                            Circle()
                                .fill(isRunning ? DS.activeGradient : DS.stopGradient)
                                .frame(width: 64, height: 64)
                                .shadow(color: (isRunning ? Color.green : Color.red).opacity(0.35), radius: 12, x: 0, y: 6)
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "power")
                                    .font(DesignTokens.Typography.title2.weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isChecking)
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .frame(height: 108)
        }
        
        private var statusColor: Color {
            if isRunning { return .green }
            if isChecking { return .yellow }
            return .red
        }
    }
    
    // MARK: - List Item
    struct ListItem: View {
        let title: String
        let subtitle: String?
        let icon: String?
        let trailing: AnyView?
        let action: (() -> Void)?
        
        init(title: String, subtitle: String? = nil, icon: String? = nil, trailing: AnyView? = nil, action: (() -> Void)? = nil) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.trailing = trailing
            self.action = action
        }
        
        var body: some View {
            Button(action: { action?() }) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(DesignTokens.Typography.headline)
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundColor(.primary)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let trailing = trailing {
                        trailing
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm + 2)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(action != nil ? Color.primary.opacity(0.03) : Color.clear)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(action == nil)
        }
    }
    
    // MARK: - Action Bar
    struct ActionBar: View {
        let actions: [Action]
        
        struct Action {
            let title: String?
            let icon: String
            let color: Color
            let isDestructive: Bool
            let action: () -> Void
        }
        
        var body: some View {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(actions.indices, id: \.self) { index in
                    let act = actions[index]
                    Button(action: act.action) {
                        if let title = act.title {
                            Label(title, systemImage: act.icon)
                                .font(DesignTokens.Typography.footnote.weight(.semibold))
                        } else {
                            Image(systemName: act.icon)
                                .font(DesignTokens.Typography.callout)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(color: act.isDestructive ? .red : act.color, variant: .ghost))
                    .frame(width: act.title == nil ? 40 : nil)
                }
            }
            .padding(DesignTokens.Spacing.xs)
            .background(DS.glassBackground())
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DS.strokeColor, lineWidth: 1)
            )
            .cornerRadius(DesignTokens.Radius.md)
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
    }
}