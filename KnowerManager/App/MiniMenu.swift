import SwiftUI

struct MiniMenu: View {
    @ObservedObject var manager = KnowerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var ocrManager = OCRManager.shared
    @ObservedObject var tools = ToolsManager.shared
    @StateObject var knowerWatch = KnowerWatchService.shared
    
    @State private var showRoutingSheet = false
    
    var displayPing: Int {
        return tools.pingTargets.first?.currentPing ?? 0
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    private var gatewayBinding: Binding<Bool> {
        Binding<Bool>(
            get: { manager.isGatewayEnabled },
            set: { newValue in
                if newValue { openSharingSettings() }
                manager.isGatewayEnabled = newValue
            }
        )
    }
    
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
                mainControlsSection
                featuresGrid
                quickToolsSection
            }
            .padding(12)
            
            Divider()
            footerSection
        }
        .frame(width: 320)
        .background(AppThemeTokens.Surface.glass)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppThemeTokens.Border.subtle, lineWidth: 1))
        .sheet(isPresented: $showRoutingSheet) {
            RoutingSheet()
                .preferredColorScheme(currentColorScheme)
        }
        .preferredColorScheme(currentColorScheme)
        // Обновляем вид при смене языка или темы
        .id("\(settings.currentTheme.rawValue)-\(settings.currentLanguage.rawValue)")
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()                    // Разрешаем изменение размера
                    .aspectRatio(contentMode: .fit) // Сохраняем пропорции
                    .frame(width: 16, height: 16)   // Задаем размер (подберите под размер текста, обычно 18-24)
                Text(settings.t(.appTitle))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(manager.isRunning ? Color.green : (manager.isChecking ? Color.yellow : Color.red))
                    .frame(width: 6, height: 6)
                    .shadow(color: (manager.isRunning ? Color.green : Color.red).opacity(0.5), radius: 2)
                
                Text(manager.isRunning ? settings.t(.mmOn) : settings.t(.mmOff))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(manager.isRunning ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .padding(12)
        .background(AppThemeTokens.Surface.elevated)
    }
    
    private var mainControlsSection: some View {
        HStack(spacing: 8) {
            // Карточка стратегии
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(settings.t(.titleStrategy).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Button(action: { manager.runChecker() }) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10))
                                .foregroundColor(.purple)
                                .padding(4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(manager.isRunning || manager.isChecking)
                        .help(settings.t(.btnAutoCheck))
                        
                        Button(action: { showRoutingSheet = true }) {
                            Image(systemName: getRoutingIcon())
                                .font(.system(size: 10))
                                .foregroundColor(getRoutingColor())
                                .padding(4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(manager.isRunning)
                        .help(settings.t(.routingTitle))
                    }
                }
                
                Menu {
                    ForEach(BypassStrategy.allCases) { s in
                        Button(action: { manager.selectedStrategy = s }) {
                            HStack { Text(s.localizedName); if manager.selectedStrategy == s { Image(systemName: "checkmark") } }
                        }
                    }
                } label: {
                    HStack {
                        Text(manager.selectedStrategy.localizedName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(manager.isRunning || manager.isChecking)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.cardColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.strokeColor, lineWidth: 1))
            
            // Power Button
            Button(action: { manager.toggleService() }) {
                ZStack {
                    Circle()
                        .fill(manager.isRunning ? DesignSystem.activeGradient : DesignSystem.stopGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: (manager.isRunning ? Color.green : Color.red).opacity(0.3), radius: 4, y: 2)
                    
                    if manager.isChecking {
                        ProgressView().scaleEffect(0.5).colorScheme(.dark)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(manager.isChecking)
        }
    }
    
    private func getRoutingIcon() -> String {
        switch manager.routingMode {
        case .global: return "globe"
        case .onlyList: return "list.bullet.rectangle.portrait.fill"
        case .exclude: return "xmark.shield.fill"
        }
    }
    
    private func getRoutingColor() -> Color {
        switch manager.routingMode {
        case .global: return .blue
        case .onlyList: return .orange
        case .exclude: return .red
        }
    }
    
    private var featuresGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            MiniFeatureToggle(title: "YouTube", icon: "play.rectangle.fill", color: .red, isOn: $settings.fixYoutube)
            MiniFeatureToggle(title: "Discord", icon: "bubble.left.and.bubble.right.fill", color: Color(NSColor.systemIndigo), isOn: $settings.fixDiscord)
            MiniFeatureToggle(title: "Gateway", icon: "wifi", color: .blue, isOn: gatewayBinding)
            MiniFeatureToggle(title: "KillSwitch", icon: "shield.slash.fill", color: .orange, isOn: $settings.killSwitchEnabled)
            MiniFeatureToggle(title: "KnowerWatch", icon: "eye.fill", color: .green, isOn: $knowerWatch.isEnabled)
            MiniFeatureToggle(title: settings.t(.notificationsTitle), icon: "bell.badge.fill", color: .red, isOn: $settings.showNotifications)
            MiniFeatureToggle(title: settings.t(.hideDockTitle), icon: "dock.rectangle", color: .purple, isOn: $settings.hideDockIcon)
            MiniFeatureToggle(title: settings.t(.launchAtLogin), icon: "paperplane.fill", color: .blue, isOn: $settings.isLaunchAtLoginEnabled)
        }
        .onChange(of: settings.fixYoutube) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: settings.fixDiscord) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: manager.isGatewayEnabled) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: settings.killSwitchEnabled) { enabled in
            if !manager.isRunning {
                if enabled { manager.enableKillSwitch() } else { manager.disableKillSwitch() }
            }
        }
    }
    
    private var quickToolsSection: some View {
        HStack(spacing: 8) {
            Button(action: { ocrManager.captureArea() }) {
                HStack(spacing: 4) {
                    Image(systemName: "text.viewfinder")
                    Text(settings.t(.tabScanner))
                }
                .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(MiniToolButtonStyle())
            
            Menu {
                ForEach(DNSServer.allCases) { dns in
                    Button(action: { settings.dnsServer = dns }) {
                        HStack { Text(dns.rawValue); if settings.dnsServer == dns { Image(systemName: "checkmark") } }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                    Text("DNS")
                }
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(DesignSystem.cardColor)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignSystem.strokeColor, lineWidth: 1))
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .disabled(manager.isRunning)
        }
    }
    
    // MARK: - FOOTER (ИСПРАВЛЕННЫЙ)
    
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
                
                // About (ВЕРНУЛИ!)
                Button(action: { MenuBarManager.shared.openAbout() }) {
                    Image(systemName: "info.circle")
                        .font(DesignTokens.Typography.callout.weight(.medium))
                }
                .buttonStyle(IconButtonStyle())
                .foregroundColor(.secondary)
                .help(settings.t(.menuAbout))
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
            
            // ГРУППА 3: СТАТУС И ВЫХОД
            HStack(spacing: 8) {
                if manager.isRunning {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform.path.ecg")
                        Text("\(displayPing)")
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(displayPing < 100 ? .green : .orange)
                }
                
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
    
    private func openSharingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.sharing") {
            NSWorkspace.shared.open(url)
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
