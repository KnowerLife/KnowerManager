import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - DESIGN SYSTEM (Legacy compatibility)
enum DesignSystem {
    static let cornerRadius: CGFloat = 16
    static let innerPadding: CGFloat = 20
    static let width: CGFloat = 380
    static let heightCollapsed: CGFloat = 780
    static let heightExpanded: CGFloat = 880
    
    static let cardColor = AppThemeTokens.Surface.elevated
    static let strokeColor = AppThemeTokens.Border.normal
    static let cardStroke = AppThemeTokens.Border.normal
    
    static let activeGradient = AppThemeTokens.Accent.success
    static let stopGradient = AppThemeTokens.Accent.danger
    static let primaryGradient = AppThemeTokens.Accent.primary
}

struct ContentView: View {
    @ObservedObject var manager = KnowerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @StateObject var warpManager = WarpManager.shared
    @ObservedObject var ocrManager = OCRManager.shared
    @ObservedObject var tools = ToolsManager.shared
    
    @State private var isLogExpanded = false
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var pulse: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Верхний бар
                ModernTopBar(settings: settings, selectedTab: $selectedTab, showSettings: $showSettings)
                    .padding(.top, 18).padding(.horizontal, 18).padding(.bottom, 14)
                
                // 2. Контент вкладок
                ZStack {
                    if selectedTab == 0 {
                        // --- ТАБ 0: ОБХОД (Zapret) ---
                        BypassDashboardView(manager: manager, settings: settings, pulse: $pulse)
                            .transition(.opacity)
                    } else if selectedTab == 1 {
                        // --- ТАБ 1: VPN (Xray) ---
                        SSConnectionView()
                            .padding(.horizontal, 18)
                            .transition(.opacity)
                    } else if selectedTab == 2 {
                        // --- ТАБ 2: WARP ---
                        WarpGeneratorView(warpManager: warpManager, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    } else if selectedTab == 3 {
                        // --- ТАБ 3: СКАНЕР ---
                        ScannerView(ocrManager: ocrManager, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    } else {
                        // --- ТАБ 4: ИНСТРУМЕНТЫ ---
                        ToolsView(tools: tools, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                Spacer(minLength: 0)
            }
            .padding(.bottom, isLogExpanded ? 150 : 22)
            
            // Лог (Показываем на вкладке "Обход", так как там логи Zapret)
            // Если вы хотите видеть логи Xray, можно добавить || selectedTab == 1
            if selectedTab == 0 {
                LogDrawer(manager: manager, settings: settings, isExpanded: $isLogExpanded).zIndex(10)
            }
        }
        .frame(width: DesignSystem.width)
        .frame(minHeight: isLogExpanded ? DesignSystem.heightExpanded : DesignSystem.heightCollapsed)
        .preferredColorScheme(settings.currentTheme == .dark ? .dark : (settings.currentTheme == .light ? .light : nil))
        .background(WindowAccessor { w in
            w.standardWindowButton(.zoomButton)?.isHidden = false
            w.standardWindowButton(.zoomButton)?.isEnabled = true
            let minH = isLogExpanded ? DesignSystem.heightExpanded : DesignSystem.heightCollapsed
            w.minSize = CGSize(width: DesignSystem.width, height: minH)
            w.maxSize = CGSize(width: DesignSystem.width, height: 2000)
            if w.frame.height < minH {
                var f = w.frame; f.origin.y -= (minH - f.height); f.size.height = minH
                w.setFrame(f, display: true, animate: true)
            }
        })
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulse = 1.1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchTab"))) { note in
            if let tab = note.userInfo?["tab"] as? Int, (0...4).contains(tab) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
            }
        }
    }
}

struct ModernTopBar: View {
    @ObservedObject var settings: SettingsManager
    @Binding var selectedTab: Int
    @Binding var showSettings: Bool
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppThemeTokens.Border.subtle, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.t(.appTitle))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Network Control Suite")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }
                }
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "sliders.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(ScaleButtonStyle())
                .sheet(isPresented: $showSettings) { GeneralSettingsSheet() }
                .help("Настройки")
            }
            let tabs = [
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabBypass), icon: "network", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.vpnTitle), icon: "lock.shield", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabWarp), icon: "key.fill", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabScanner), icon: "text.viewfinder", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabTools), icon: "wrench.and.screwdriver.fill", badge: nil)
            ]
            UXUIKit.ModernTabBar(selectedTab: $selectedTab, tabs: tabs, namespace: animation)
        }
    }
}

// MARK: - REST OF CONTENT VIEW (BYPASS, WARP, ETC)
struct BypassDashboardView: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings: SettingsManager
    @Binding var pulse: CGFloat
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                StatusHeaderCard(manager: manager, settings: settings, pulse: pulse)
                
                if !manager.isFileReady {
                    InstallCardView(manager: manager, settings: settings)
                } else {
                    // Здесь обновленный Grid с волшебной палочкой
                    ConfigurationGrid(manager: manager, settings: settings)
                    
                    FeaturesGrid(manager: manager, settings: settings)
                    if manager.isGatewayEnabled { GatewayInfoCard(manager: manager) }
                }
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct WarpGeneratorView: View {
    @ObservedObject var warpManager: WarpManager; @ObservedObject var settings: SettingsManager
    @State private var showSettingsSheet = false; @State private var showQRCodeSheet = false; @State private var showScannerSheet = false
    var body: some View { VStack(spacing: 12) { VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "key.icloud.fill").font(.system(size: 20)).foregroundColor(.purple); Text(settings.t(.warpTitle)).font(.system(size: 16, weight: .bold, design: .rounded)); Spacer(); Button(action: { showSettingsSheet = true }) { Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle()).frame(width: 36, height: 30).background(Color.black.opacity(0.05)).cornerRadius(8) }; Divider().background(Color.secondary.opacity(0.2)); HStack { Image(systemName: "network").font(.caption).foregroundColor(.secondary); Text(warpManager.proxyStatus).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary); Spacer(); Button(action: { warpManager.detectProxy() }) { if warpManager.isScanningProxy { ProgressView().scaleEffect(0.5).frame(width: 24, height: 24) } else { Image(systemName: "wand.and.stars").font(.system(size: 14)).foregroundColor(.blue).frame(width: 24, height: 24).background(Color.blue.opacity(0.1)).cornerRadius(6) } }.buttonStyle(PlainButtonStyle()).disabled(warpManager.isScanningProxy).help(settings.t(.btnScan)) } }.padding(12).background(DesignSystem.cardColor).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.strokeColor, lineWidth: 1)); VStack(spacing: 8) { HStack { Text(settings.t(.warpFormat)).font(.caption).foregroundColor(.secondary); Spacer(); Picker("", selection: $warpManager.selectedFormat) { ForEach(ExportFormat.allCases) { format in Text(format.rawValue).tag(format) } }.labelsHidden().frame(width: 140) }; HStack { TextField(settings.t(.endpointAuto), text: $warpManager.customEndpoint).textFieldStyle(RoundedBorderTextFieldStyle()).font(.system(size: 11, design: .monospaced)); Button(action: { showScannerSheet = true }) { Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(.blue) }.buttonStyle(PlainButtonStyle()).frame(width: 28, height: 28).background(Color.blue.opacity(0.1)).cornerRadius(6).help(settings.t(.endpointScanHelp)) } }.padding(8).background(DesignSystem.cardColor).cornerRadius(10); Button(action: { warpManager.generateConfig() }) { if warpManager.isGenerating { ProgressView().scaleEffect(0.5).frame(maxWidth: .infinity) } else { HStack { Image(systemName: "sparkles"); Text(settings.t(.btnGenerate)) }.font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white).frame(maxWidth: .infinity) } }.frame(height: 44).background(Color.purple).cornerRadius(12).shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3).buttonStyle(PlainButtonStyle()).disabled(warpManager.isGenerating); TextEditor(text: .constant(warpManager.generatedConfig)).font(.system(size: 10, design: .monospaced)).padding(6).background(Color(NSColor.textBackgroundColor).opacity(0.5)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.strokeColor, lineWidth: 1)).frame(maxHeight: .infinity); if !warpManager.generatedConfig.isEmpty { HStack(spacing: 12) { Button(action: { showQRCodeSheet = true }) { Label("QR", systemImage: "qrcode") }.buttonStyle(ModernButtonStyle(color: .gray)).disabled(warpManager.isConfigTooLargeForQR); if #available(macOS 13.0, *) { ShareLink(item: warpManager.generatedConfig) { Label(settings.t(.btnShare), systemImage: "square.and.arrow.up").font(.system(size: 11, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.blue).foregroundColor(.white).cornerRadius(8) }.buttonStyle(PlainButtonStyle()) } else { Button(action: { warpManager.copyToClipboard() }) { Label(settings.t(.btnCopy), systemImage: "doc.on.doc") }.buttonStyle(ModernButtonStyle(color: .blue)) }; Button(action: { warpManager.saveToFile() }) { Label(settings.t(.btnSaveFile), systemImage: "square.and.arrow.down") }.buttonStyle(ModernButtonStyle(color: .green)) }.frame(height: 32) }; if !warpManager.statusMessage.isEmpty { Text(warpManager.statusMessage).font(.caption).foregroundColor(.secondary) } }.onAppear { warpManager.detectProxy() }.sheet(isPresented: $showSettingsSheet) { WarpSettingsSheet(warpManager: warpManager) }.sheet(isPresented: $showQRCodeSheet) { QRCodeSheet(image: warpManager.qrCodeImage, configName: warpManager.selectedFormat.rawValue) }.sheet(isPresented: $showScannerSheet) { ScannerSheet() } }
}

// ModernTabButton deprecated - use UXUIKit.ModernTabBar

struct StatusHeaderCard: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings: SettingsManager
    var pulse: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(manager.isRunning ? Color.green.opacity(0.1) : Color.red.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(manager.isRunning ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(manager.isRunning ? Color.green : (manager.isChecking ? Color.yellow : Color.red))
                            .frame(width: 8, height: 8)
                        
                        // L O C A L I Z E D
                        Text(manager.isRunning ? settings.t(.statusProtected) : settings.t(.statusDisconnected))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(manager.isRunning ? .green : .secondary)
                    }
                    Text(manager.statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: { manager.toggleService() }) {
                    ZStack {
                        Circle()
                            .fill(manager.isRunning ? DesignSystem.activeGradient : DesignSystem.stopGradient)
                            .frame(width: 60, height: 60)
                            .shadow(color: (manager.isRunning ? Color.green : Color.red).opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        if manager.isChecking {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "power")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(manager.isChecking)
            }
            .padding(20)
        }
        .frame(height: 100)
    }
}
struct ConfigurationGrid: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings: SettingsManager
    @State private var showRoutingSheet = false
    
    // Вспомогательные функции для UI (чтобы не загромождать body)
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
    
    private func getRoutingText() -> String {
        switch manager.routingMode {
        case .global: return settings.t(.routingModeGlobal)
        case .onlyList: return settings.t(.routingModeList)
        case .exclude: return settings.t(.routingModeExclude)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Блок Стратегии
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(settings.t(.titleStrategy).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Группа иконок
                    HStack(spacing: 6) {
                        // 1. ВОЛШЕБНАЯ ПАЛОЧКА (Auto Check)
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
                        
                        // 2. ПЛАНЕТА / СПИСОК / ИСКЛЮЧЕНИЯ (Routing)
                        Button(action: { showRoutingSheet = true }) {
                            // ИСПРАВЛЕНО: Используем функции для иконки и цвета
                            Image(systemName: getRoutingIcon())
                                .font(.system(size: 10))
                                .foregroundColor(getRoutingColor())
                                .padding(4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(manager.isRunning)
                    }
                }
                .padding(.bottom, 6)
                
                // Выпадающее меню стратегий
                Menu {
                    ForEach(BypassStrategy.allCases) { s in
                        Button(action: { manager.selectedStrategy = s }) {
                            HStack {
                                Text(s.localizedName)
                                if manager.selectedStrategy == s { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.selectedStrategy.localizedName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            // ИСПРАВЛЕНО: Текст режима маршрутизации
                            Text(getRoutingText())
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(manager.isRunning)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
            .cornerRadius(12)
            .sheet(isPresented: $showRoutingSheet) { RoutingSheet() }
            
            // Блок DNS
            VStack(alignment: .leading, spacing: 0) {
                Text(settings.t(.titleDNS).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
                
                Menu {
                    ForEach(DNSServer.allCases) { dns in
                        Button(action: { settings.dnsServer = dns }) {
                            HStack {
                                Text(dns.rawValue)
                                if settings.dnsServer == dns { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.dnsServer.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("Resolver")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(manager.isRunning)
            }
            .padding(12)
            .frame(width: 120)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
            .cornerRadius(12)
        }
        
        if manager.selectedStrategy == .custom {
            CustomStrategyBuilder(manager: manager, settings: settings)
        }
    }
}

struct FeaturesGrid: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings: SettingsManager
    
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    
    var body: some View {
        // Создаем "умную" привязку для Gateway
        let gatewayBinding = Binding<Bool>(
            get: { manager.isGatewayEnabled },
            set: { newValue in
                // Добавляем тактильный отклик
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                
                manager.isGatewayEnabled = newValue
                // Если включаем - открываем настройки
                if newValue {
                    openSharingSettings()
                }
            }
        )
        
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t(.fixesTitle).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            LazyVGrid(columns: columns, spacing: 12) {
                // ИСПРАВЛЕНО: Добавлена локализация (fixYtTitle, fixDsTitle)
                ModernFeatureToggle(
                    title: settings.t(.fixYtTitle),
                    icon: "play.rectangle.fill",
                    color: .red,
                    isOn: $settings.fixYoutube
                )
                
                ModernFeatureToggle(
                    title: settings.t(.fixDsTitle),
                    icon: "bubble.left.and.bubble.right.fill",
                    color: Color(NSColor.systemIndigo),
                    isOn: $settings.fixDiscord
                )
                
                // ИСПРАВЛЕНО: Добавлена локализация (gatewayTitle)
                ModernFeatureToggle(
                    title: settings.t(.gatewayTitle),
                    icon: "wifi",
                    color: .blue,
                    isOn: gatewayBinding
                )
                
                // ИСПРАВЛЕНО: Логика иконки (Включено = shield.fill, Выключено = shield)
                ModernFeatureToggle(
                    title: settings.t(.killSwitchTitle),
                    icon: settings.killSwitchEnabled ? "shield.fill" : "shield",
                    color: .orange,
                    isOn: $settings.killSwitchEnabled
                )
            }
        }
        // Ваши .onChange правильные, они вызовут обновление правил
        // и благодаря нашим правкам в KnowerManager пароль спросят только один раз (или возьмут из Keychain)
        .onChange(of: settings.fixYoutube) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: settings.fixDiscord) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: manager.isGatewayEnabled) { _ in manager.updateFirewallRulesIfNeeded() }
        .onChange(of: settings.killSwitchEnabled) { enabled in
            if !manager.isRunning {
                if enabled { manager.enableKillSwitch() } else { manager.disableKillSwitch() }
            }
        }
    }
    
    private func openSharingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.sharing") {
            NSWorkspace.shared.open(url)
        }
    }
}
struct ModernFeatureToggle: View { let title: String; let icon: String; let color: Color; @Binding var isOn: Bool; var body: some View { Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isOn.toggle() } }) { HStack { ZStack { Circle().fill(isOn ? color : Color.gray.opacity(0.1)).frame(width: 32, height: 32); Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(isOn ? .white : .secondary) }; Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(isOn ? .primary : .secondary); Spacer(); if isOn { Circle().fill(color).frame(width: 6, height: 6).shadow(color: color.opacity(0.5), radius: 2) } }.padding(12).background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor)).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)).overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? color.opacity(0.5) : Color.clear, lineWidth: 1)) }.buttonStyle(ScaleButtonStyle()) } }
struct GatewayInfoCard: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings = SettingsManager.shared // Добавлено для доступа к локализации
    @State private var isCopiedIP = false
    @State private var isCopiedPAC = false
    
    var body: some View {
        if let ip = manager.getBridgeIP() {
            // --- БЛОК: СЕТЬ НАЙДЕНА (АКТИВНО) ---
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                    // L O C A L I Z E D
                    Text(settings.t(.gatewayActive))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                HStack(spacing: 10) {
                    InfoBox(title: "IP", value: ip, icon: "network", isCopied: isCopiedIP) {
                        copyToClipboard(ip)
                        isCopiedIP = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopiedIP = false }
                    }
                    InfoBox(title: "PAC URL", value: "http://\(ip):8080/proxy.pac", icon: "link", isCopied: isCopiedPAC) {
                        copyToClipboard("http://\(ip):8080/proxy.pac")
                        isCopiedPAC = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopiedPAC = false }
                    }
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            .transition(.scale.combined(with: .opacity))
            
        } else {
            // --- БЛОК: ОЖИДАНИЕ СЕТИ (С КНОПКОЙ) ---
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        // L O C A L I Z E D
                        Text(settings.t(.gatewayWaiting))
                            .font(.system(size: 12, weight: .bold))
                    }
                    // L O C A L I Z E D
                    Text(settings.t(.gatewayEnableHint))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 18)
                }
                
                Spacer()
                
                // L O C A L I Z E D
                Button(settings.t(.btnOpenSettings)) {
                    // Открываем настройки "Общий доступ"
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.sharing") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(ModernButtonStyle(color: .gray))
                .frame(width: 100)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.strokeColor, lineWidth: 1))
            // Таймер: обновляет UI каждые 2 секунды, проверяя, появился ли IP
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                manager.objectWillChange.send()
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
struct InfoBox: View { let title: String; let value: String; let icon: String; let isCopied: Bool; let action: () -> Void; var body: some View { Button(action: action) { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary); HStack { Text(isCopied ? "Copied!" : value).font(.system(size: 10, design: .monospaced)).lineLimit(1).truncationMode(.tail); Spacer(); if isCopied { Image(systemName: "checkmark").font(.caption).foregroundColor(.green) } } }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.5)).cornerRadius(8) }.buttonStyle(PlainButtonStyle()) } }
struct LogDrawer: View { @ObservedObject var manager: KnowerManager; @ObservedObject var settings: SettingsManager; @Binding var isExpanded: Bool; var body: some View { LogDrawerView(manager: manager, settings: settings, isExpanded: $isExpanded) } }
struct LogDrawerView: View { @ObservedObject var manager: KnowerManager; @ObservedObject var settings: SettingsManager; @Binding var isExpanded: Bool; var body: some View { VStack(spacing: 0) { Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isExpanded.toggle() } }) { VStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.3)).frame(width: 30, height: 4).padding(.top, 8); HStack { Circle().fill(manager.isRunning ? Color.green : Color.secondary).frame(width: 6, height: 6); Text(isExpanded ? settings.t(.titleLog) : lastLogLine).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).lineLimit(1); Spacer() }.padding(.horizontal, 16).padding(.bottom, 8) }.frame(height: 36).background(VisualEffectView(material: .headerView, blendingMode: .withinWindow)) }.buttonStyle(PlainButtonStyle()); if isExpanded { ZStack(alignment: .topTrailing) { ScrollViewReader { reader in ScrollView { Text(manager.consoleOutput.isEmpty ? "> ..." : manager.consoleOutput).font(.system(size: 10, design: .monospaced)).foregroundColor(Color(NSColor.textColor)).frame(maxWidth: .infinity, alignment: .leading).padding(12).id("bottom").onChange(of: manager.consoleOutput) { _ in reader.scrollTo("bottom", anchor: .bottom) } } }; Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(manager.consoleOutput, forType: .string) }) { Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundColor(.secondary).padding(6).background(Color(NSColor.controlBackgroundColor).opacity(0.8)).cornerRadius(6) }.buttonStyle(PlainButtonStyle()).padding(8) }.frame(height: 140).background(Color(NSColor.textBackgroundColor)) } }.background(Color(NSColor.windowBackgroundColor)).clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight])).shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -2) }; var lastLogLine: String { let lines = manager.consoleOutput.split(separator: "\n"); return String(lines.last ?? "> ...") } }
struct InstallCardView: View { @ObservedObject var manager: KnowerManager; @ObservedObject var settings: SettingsManager; var body: some View { VStack(spacing: 16) { Image(systemName: "externaldrive.badge.icloud").font(.system(size: 30)).foregroundColor(.secondary); Text(settings.t(.setupDesc)).font(.subheadline).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal); if manager.isDownloading { ProgressView().scaleEffect(0.8) } else { HStack { Button(settings.t(.btnAutoInstall)) { manager.downloadTpws() }.buttonStyle(ModernButtonStyle(color: .blue)); Button(action: { manager.selectLocalFile() }) { Image(systemName: "folder") }.buttonStyle(ModernButtonStyle(color: .gray)).frame(width: 50) } } }.padding(20).background(DesignSystem.cardColor).cornerRadius(DesignSystem.cornerRadius).overlay(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius).stroke(DesignSystem.strokeColor, lineWidth: 1)) } }
struct CustomStrategyBuilder: View {
    @ObservedObject var manager: KnowerManager
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t(.builderTitle))
                .font(.caption2)
                .bold()
                .foregroundColor(.secondary)
            
            TextField(settings.t(.stratCustomPlaceholder), text: $manager.customArgs)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            
            // ГОРИЗОНТАЛЬНАЯ ПРОКРУТКА
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    BuilderToggle(title: "--disorder", current: $manager.customArgs)
                    BuilderToggle(title: "--fake", current: $manager.customArgs)
                    BuilderToggle(title: "--auto=torst", current: $manager.customArgs)
                    BuilderToggle(title: "--split-pos=1", current: $manager.customArgs)
                    BuilderToggle(title: "--hostlist", current: $manager.customArgs)
                    BuilderToggle(title: "--ttl=3", current: $manager.customArgs)
                    BuilderToggle(title: "--oob", current: $manager.customArgs)
                    BuilderToggle(title: "--badseq", current: $manager.customArgs)
                    BuilderToggle(title: "--hostcase", current: $manager.customArgs)
                    BuilderToggle(title: "--split-pos=2", current: $manager.customArgs)
                    BuilderToggle(title: "--split-any-protocol", current: $manager.customArgs)
                    BuilderToggle(title: "--tlsrec=sni+2", current: $manager.customArgs)
                    BuilderToggle(title: "--mss=1200", current: $manager.customArgs)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(DesignSystem.cardColor)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignSystem.strokeColor, lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
        .disabled(manager.isRunning)
    }
}

struct QRCodeSheet: View { let image: NSImage?; let configName: String; @Environment(\.presentationMode) var presentationMode; var body: some View { VStack(spacing: 20) { HStack { Text(SettingsManager.shared.t(.qrTitle)).font(.headline); Spacer(); Button(SettingsManager.shared.t(.btnDone)) { presentationMode.wrappedValue.dismiss() }.buttonStyle(PlainButtonStyle()).foregroundColor(.blue) }.padding().background(VisualEffectView(material: .headerView, blendingMode: .withinWindow)); VStack(spacing: 10) { if let nsImage = image { Image(nsImage: nsImage).resizable().interpolation(.none).scaledToFit().frame(width: 250, height: 250).padding().background(Color.white).cornerRadius(12).shadow(radius: 5); Text("\(SettingsManager.shared.t(.qrScanHint)) \(configName)").font(.subheadline).foregroundColor(.secondary) } else { Image(systemName: "xmark.circle").font(.system(size: 50)).foregroundColor(.red); Text(SettingsManager.shared.t(.qrFailedTitle)).font(.headline); Text(SettingsManager.shared.t(.qrFailedDesc)).font(.caption).foregroundColor(.secondary) } }.padding(.bottom, 30); Spacer() }.frame(width: 380, height: 450) } }
struct ScannerSheet: View {
    @ObservedObject var scanner = IPScanner.shared
    @ObservedObject var warpManager = WarpManager.shared
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(settings.t(.ipScanTitle)).font(.headline)
                Spacer()
                Button(settings.t(.btnDone)) {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            VStack(spacing: 16) {
                // Info & Control Panel
                HStack {
                    VStack(alignment: .leading) {
                        Text(settings.t(.ipScanBestIP))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(scanner.bestIP ?? settings.t(.notFound))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    if scanner.isScanning {
                        ProgressView(value: scanner.progress)
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Button(action: { scanner.startScan() }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(settings.t(.ipScanStart))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // List of Results
                List {
                    // L O C A L I Z E D: "Results" -> settings.t(.scanResults)
                    Section(header: Text(settings.t(.scanResults))) {
                        ForEach(scanner.scannedIPs) { item in
                            HStack {
                                Circle()
                                    .fill(latencyColor(item.latency))
                                    .frame(width: 8, height: 8)
                                
                                Text("\(item.ip):\(item.port)")
                                    .font(.system(size: 13, design: .monospaced))
                                
                                Spacer()
                                
                                Text(String(format: "%.0f ms", item.latency))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                // L O C A L I Z E D: "Use" -> settings.t(.btnUse)
                                Button(settings.t(.btnUse)) {
                                    warpManager.customEndpoint = "\(item.ip):\(item.port)"
                                    presentationMode.wrappedValue.dismiss()
                                }
                                .font(.system(size: 10))
                                .buttonStyle(BorderedButtonStyle())
                            }
                        }
                    }
                }
                .listStyle(InsetListStyle())
            }
            .padding()
        }
        .frame(width: 380, height: 500)
    }
    
    func latencyColor(_ ms: Double) -> Color {
        ms < 50 ? .green : (ms < 150 ? .orange : .red)
    }
}
struct AIConfigSheet: View { @ObservedObject var ocrManager: OCRManager; @Environment(\.presentationMode) var presentationMode; @ObservedObject var settings = SettingsManager.shared; var body: some View { VStack(spacing: 20) { Text(settings.t(.ocrAISettings)).font(.headline); Form { Toggle(settings.t(.aiEnable), isOn: $ocrManager.aiService.config.enabled); Picker(settings.t(.aiProvider), selection: $ocrManager.aiService.config.provider) { ForEach(AIServiceProvider.allCases) { provider in Text(provider.rawValue).tag(provider) } }; if ocrManager.aiService.config.provider != .local { SecureField(settings.t(.aiApiKey), text: $ocrManager.aiService.config.apiKey) }; Picker(settings.t(.aiModel), selection: $ocrManager.aiService.config.model) { ForEach(ocrManager.aiService.config.provider.availableModels, id: \.self) { model in Text(model).tag(model) } } }.padding(); HStack { Button(settings.t(.btnCancel)) { presentationMode.wrappedValue.dismiss() }; Button(settings.t(.btnSave)) { ocrManager.aiService.saveConfig(); presentationMode.wrappedValue.dismiss() }.buttonStyle(ModernButtonStyle(color: .blue)) } }.frame(width: 380, height: 300).padding() } }

// Legacy button styles removed - use Design components
struct VisualEffectView: NSViewRepresentable { let material: NSVisualEffectView.Material; let blendingMode: NSVisualEffectView.BlendingMode; func makeNSView(context: Context) -> NSVisualEffectView { let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = .active; return v }; func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.material = material; nsView.blendingMode = blendingMode } }
struct WindowAccessor: NSViewRepresentable { var callback: (NSWindow) -> Void; func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { [weak view] in if let w = view?.window { self.callback(w) } }; return view }; func updateNSView(_ nsView: NSView, context: Context) {} }
struct RoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: RectCorner = .allCorners; func path(in rect: CGRect) -> Path { var path = Path(); let r = min(min(radius, rect.height/2), rect.width/2); let p1 = CGPoint(x: rect.minX, y: rect.minY); let p2 = CGPoint(x: rect.maxX, y: rect.minY); let p3 = CGPoint(x: rect.maxX, y: rect.maxY); let p4 = CGPoint(x: rect.minX, y: rect.maxY); if corners.contains(.topLeft) { path.move(to: CGPoint(x: p1.x, y: p1.y + r)); path.addArc(center: CGPoint(x: p1.x + r, y: p1.y + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) } else { path.move(to: p1) }; if corners.contains(.topRight) { path.addLine(to: CGPoint(x: p2.x - r, y: p2.y)); path.addArc(center: CGPoint(x: p2.x - r, y: p2.y + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false) } else { path.addLine(to: p2) }; if corners.contains(.bottomRight) { path.addLine(to: CGPoint(x: p3.x, y: p3.y - r)); path.addArc(center: CGPoint(x: p3.x - r, y: p3.y - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) } else { path.addLine(to: p3) }; if corners.contains(.bottomLeft) { path.addLine(to: CGPoint(x: p4.x + r, y: p4.y)); path.addArc(center: CGPoint(x: p4.x + r, y: p4.y - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) } else { path.addLine(to: p4) }; path.closeSubpath(); return path } }
struct RectCorner: Sendable, ExpressibleByArrayLiteral, Equatable { let rawValue: Int; init(rawValue: Int) { self.rawValue = rawValue }; init(arrayLiteral elements: RectCorner...) { var raw = 0; for element in elements { raw |= element.rawValue }; self.rawValue = raw }; func contains(_ member: RectCorner) -> Bool { return (rawValue & member.rawValue) != 0 }; static let topLeft = RectCorner(rawValue: 1 << 0); static let topRight = RectCorner(rawValue: 1 << 1); static let bottomLeft = RectCorner(rawValue: 1 << 2); static let bottomRight = RectCorner(rawValue: 1 << 3); static let allCorners = RectCorner(rawValue: 15) }
struct BuilderToggle: View { let title: String; @Binding var current: String; var isActive: Bool { current.contains(title) }; var body: some View { Button(action: { if isActive { current = current.replacingOccurrences(of: title, with: "").trimmingCharacters(in: .whitespaces) } else { current = (current + " " + title).trimmingCharacters(in: .whitespaces) } }) { Text(title).font(.system(size: 10, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 4).background(isActive ? Color.blue : Color.secondary.opacity(0.1)).foregroundColor(isActive ? .white : .primary).cornerRadius(6) }.buttonStyle(PlainButtonStyle()) } }
