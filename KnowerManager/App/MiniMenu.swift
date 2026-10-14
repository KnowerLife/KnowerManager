import SwiftUI

struct MiniMenu: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var ocrManager = OCRManager.shared
    @ObservedObject var xray = XrayService.shared
    @ObservedObject var toolStore = ToolStore.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var currentColorScheme: ColorScheme? {
        switch settings.currentTheme {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
    
    private var miniTools: [Tool] {
        toolStore.tools.filter { $0.enabled && $0.showInMiniMenu }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            VStack(spacing: 12) {
                vpnStatusSection
                quickLaunchSection
                if !miniTools.isEmpty {
                    miniToolsSection
                }
                appTogglesSection
            }
            .padding(12)
            
            Divider()
            footerSection
        }
        .frame(width: 320)
        .background(AppThemeTokens.Surface.glass)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppThemeTokens.Border.subtle, lineWidth: 1))
        .preferredColorScheme(currentColorScheme)
        .id("\(settings.currentTheme.rawValue)-\(settings.currentLanguage.rawValue)")
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(settings.t(.appTitle))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1)
            }
            Spacer()
            Text("OCR · VPN")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .padding(12)
        .background(AppThemeTokens.Surface.elevated)
    }
    
    private var vpnStatusSection: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(xray.isRunning ? Color.green.opacity(0.18) : Color.gray.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: xray.isRunning ? "shield.fill" : "shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(xray.isRunning ? .green : .secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(settings.t(.vpnTitle))
                    .font(.system(size: 10, weight: .bold))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(vpnStatusText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            Button(action: { xray.toggleConnection() }) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(canToggleConnection ? (xray.isRunning ? Color.red : Color.blue) : Color.gray.opacity(0.4))
                    .cornerRadius(8)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canToggleConnection)
            .help(xray.isRunning ? settings.t(.btnDisconnect) : settings.t(.btnConnect))
        }
        .padding(8)
        .background(DesignSystem.cardColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(xray.isRunning ? Color.green.opacity(0.35) : DesignSystem.strokeColor, lineWidth: 1))
    }
    
    private var canToggleConnection: Bool {
        xray.isRunning || xray.selectedProfileId != nil
    }
    
    private var vpnStatusText: String {
        if xray.isRunning {
            let uptime = uptimeShort
            if let id = xray.activeProfileId, let profile = xray.profiles.first(where: { $0.id == id }) {
                return "\(settings.t(.vpnConnected)) · \(profile.name) · \(uptime)"
            }
            return "\(settings.t(.vpnConnected)) · \(uptime)"
        }
        if let id = xray.selectedProfileId, let profile = xray.profiles.first(where: { $0.id == id }) {
            return profile.name
        }
        return settings.t(.vpnNotConnected)
    }
    
    private var uptimeShort: String {
        let total = Int(xray.connectionUptime)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    private var quickLaunchSection: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            actionTile(title: settings.t(.vpnTitle), icon: "lock.shield", color: .green) {
                MenuBarManager.shared.openMainWindow(tab: 0)
            }
            actionTile(title: settings.t(.tabOcr), icon: "text.viewfinder", color: .blue) {
                MenuBarManager.shared.openMainWindow(tab: 1)
            }
            actionTile(title: settings.t(.ocrArea), icon: "viewfinder", color: .pink) {
                ocrManager.captureArea()
            }
        }
    }
    
    private var miniToolsSection: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(miniTools) { tool in
                if tool.id == "keepAwake" {
                    MiniStatusTile(title: settings.t(.toolKeepAwakeMini), icon: "moon.zzz.fill", color: .purple)
                }
            }
        }
    }
    
    private var appTogglesSection: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            MiniFeatureToggle(title: settings.t(.notificationsTitle), icon: "bell.badge.fill", color: .red, isOn: $settings.showNotifications)
            MiniFeatureToggle(title: settings.t(.hideDockTitle), icon: "dock.rectangle", color: .purple, isOn: $settings.hideDockIcon)
            MiniFeatureToggle(title: settings.t(.launchAtLogin), icon: "paperplane.fill", color: .blue, isOn: $settings.isLaunchAtLoginEnabled)
        }
    }
    
    private func actionTile(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 24, height: 24)
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                }
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(DesignSystem.cardColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.strokeColor, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    struct MiniStatusTile: View {
        let title: String; let icon: String; let color: Color
        var body: some View {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 24, height: 24)
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                }
                Text(title).font(.system(size: 9, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(DesignSystem.cardColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.strokeColor, lineWidth: 1))
        }
    }
    
    private var footerSection: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { MenuBarManager.shared.openMainWindow() }) {
                    Image(systemName: "macwindow")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.blue)
                .help(settings.t(.menuOpenShort))
                Button(action: { MenuBarManager.shared.openAbout() }) {
                    Image(systemName: "info.circle")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.secondary)
                .help(settings.t(.menuAbout))
                Button(action: { MenuBarManager.shared.openSettings() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.secondary)
                .help(settings.t(.settingsTitle))
            }
            Spacer()
            HStack(spacing: 6) {
                Menu {
                    Button("English") { settings.currentLanguage = .english }
                    Button("Русский") { settings.currentLanguage = .russian }
                } label: {
                    Text(settings.currentLanguage == .english ? "EN" : "RU")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(5)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(height: 20)
                Menu {
                    Button(action: { settings.currentTheme = .system }) {
                        Label(AppTheme.system.localizedName(language: settings.currentLanguage), systemImage: "circle.lefthalf.filled")
                    }
                    Button(action: { settings.currentTheme = .light }) {
                        Label(AppTheme.light.localizedName(language: settings.currentLanguage), systemImage: "sun.max")
                    }
                    Button(action: { settings.currentTheme = .dark }) {
                        Label(AppTheme.dark.localizedName(language: settings.currentLanguage), systemImage: "moon")
                    }
                } label: {
                    Image(systemName: themeIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(4)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 30, height: 20)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: { MenuBarManager.shared.quitApp() }) {
                    Image(systemName: "power")
                        .font(DesignTokens.Typography.callout.weight(.semibold))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.red.opacity(0.9))
                .help(settings.t(.menuQuitShort))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
    }
    
    private var themeIcon: String {
        switch settings.currentTheme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct MiniFeatureToggle: View {
    let title: String; let icon: String; let color: Color; @Binding var isOn: Bool
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isOn.toggle() } }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(isOn ? color : Color.gray.opacity(0.1)).frame(width: 24, height: 24)
                    Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(isOn ? .white : .secondary)
                }
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(isOn ? .primary : .secondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(DesignSystem.cardColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isOn ? color.opacity(0.4) : DesignSystem.strokeColor, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
