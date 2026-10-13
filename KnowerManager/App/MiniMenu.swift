import SwiftUI

struct MiniMenu: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var ocrManager = OCRManager.shared
    @ObservedObject var xray = XrayService.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    // Вычисляем цветовую схему на основе настроек
    var currentColorScheme: ColorScheme? {
        switch settings.currentTheme {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            VStack(spacing: 12) {
                vpnStatusSection
                quickLaunchSection
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
        // Обновляем вид при смене языка или темы
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
                Text(vpnStatusText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
    
    /// Можно ли переключить соединение: либо уже подключены, либо выбран профиль.
    private var canToggleConnection: Bool {
        xray.isRunning || xray.selectedProfileId != nil
    }
    
    /// Текст статуса: «Подключено · имя», имя выбранного профиля или «Не подключено».
    private var vpnStatusText: String {
        if xray.isRunning {
            if let id = xray.activeProfileId, let profile = xray.profiles.first(where: { $0.id == id }) {
                return "\(settings.t(.vpnConnected)) · \(profile.name)"
            }
            return settings.t(.vpnConnected)
        }
        if let id = xray.selectedProfileId, let profile = xray.profiles.first(where: { $0.id == id }) {
            return profile.name
        }
        return settings.t(.vpnNotConnected)
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
    
    // MARK: - FOOTER
    
    private var footerSection: some View {
        HStack(spacing: 0) {
            // ГРУППА 1: УПРАВЛЕНИЕ ОКНАМИ И ABOUT
            HStack(spacing: 8) {
                // Главное окно
                Button(action: { MenuBarManager.shared.openMainWindow() }) {
                    Image(systemName: "macwindow")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.blue)
                .help(settings.t(.menuOpenShort))
                
                // About
                Button(action: { MenuBarManager.shared.openAbout() }) {
                    Image(systemName: "info.circle")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.secondary)
                .help(settings.t(.menuAbout))
                
                // Настройки
                Button(action: { MenuBarManager.shared.openSettings() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.secondary)
                .help(settings.t(.settingsTitle))
            }
            
            Spacer()
            
            // ГРУППА 2: НАСТРОЙКИ (ЯЗЫК И ТЕМА)
            HStack(spacing: 6) {
                // Язык
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
                
                // Тема
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
            
            // ГРУППА 3: ВЫХОД
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
    
    // Иконка для кнопки темы
    private var themeIcon: String {
        switch settings.currentTheme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - MINI COMPONENTS

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

struct MiniToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(DesignSystem.cardColor.opacity(configuration.isPressed ? 0.5 : 1))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignSystem.strokeColor, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
