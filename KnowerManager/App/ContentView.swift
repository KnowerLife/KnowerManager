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
    @ObservedObject var settings = SettingsManager.shared
    @StateObject var warpManager = WarpManager.shared
    @ObservedObject var ocrManager = OCRManager.shared
    
    @State private var selectedTab = 0
    @State private var showSettings = false
    
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
                        // --- ТАБ 0: VPN (Xray) ---
                        SSConnectionView()
                            .padding(.horizontal, 18)
                            .transition(.opacity)
                    } else if selectedTab == 1 {
                        // --- ТАБ 1: WARP ---
                        WarpGeneratorView(warpManager: warpManager, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    } else {
                        // --- ТАБ 2: OCR (Сканер) ---
                        ScannerView(ocrManager: ocrManager, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 22)
        }
        .frame(width: DesignSystem.width)
        .frame(minHeight: DesignSystem.heightCollapsed)
        .preferredColorScheme(settings.currentTheme == .dark ? .dark : (settings.currentTheme == .light ? .light : nil))
        .background(WindowAccessor { w in
            w.standardWindowButton(.zoomButton)?.isHidden = false
            w.standardWindowButton(.zoomButton)?.isEnabled = true
            w.minSize = CGSize(width: DesignSystem.width, height: DesignSystem.heightCollapsed)
            let screenH = NSScreen.main?.visibleFrame.height ?? 1200
            w.maxSize = CGSize(width: DesignSystem.width, height: max(DesignSystem.heightCollapsed, screenH))
            if w.frame.height < DesignSystem.heightCollapsed {
                var f = w.frame; f.origin.y -= (DesignSystem.heightCollapsed - f.height); f.size.height = DesignSystem.heightCollapsed
                w.setFrame(f, display: true, animate: true)
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchTab"))) { note in
            if let tab = note.userInfo?["tab"] as? Int, (0...2).contains(tab) {
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
                        Text(settings.t(.appTagline))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }
                }
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(ScaleButtonStyle())
                .sheet(isPresented: $showSettings) { GeneralSettingsSheet() }
                .help(settings.t(.settingsTitle))
            }
            let tabs = [
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.vpnTitle), icon: "lock.shield", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabWarp), icon: "key.fill", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabOcr), icon: "text.viewfinder", badge: nil)
            ]
            UXUIKit.ModernTabBar(selectedTab: $selectedTab, tabs: tabs, namespace: animation)
        }
    }
}

// MARK: - REST OF CONTENT VIEW (WARP, OCR)
struct WarpGeneratorView: View {
    @ObservedObject var warpManager: WarpManager; @ObservedObject var settings: SettingsManager
    @State private var showSettingsSheet = false; @State private var showQRCodeSheet = false; @State private var showScannerSheet = false
    var body: some View { VStack(spacing: 12) { VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "key.icloud.fill").font(.system(size: 20)).foregroundColor(.purple); Text(settings.t(.warpTitle)).font(.system(size: 16, weight: .bold, design: .rounded)); Spacer(); Button(action: { showSettingsSheet = true }) { Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle()).frame(width: 36, height: 30).background(Color.black.opacity(0.05)).cornerRadius(8) }; Divider().background(Color.secondary.opacity(0.2)); HStack { Image(systemName: "network").font(.caption).foregroundColor(.secondary); Text(warpManager.proxyStatus).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary); Spacer(); Button(action: { warpManager.detectProxy() }) { if warpManager.isScanningProxy { ProgressView().scaleEffect(0.5).frame(width: 24, height: 24) } else { Image(systemName: "wand.and.stars").font(.system(size: 14)).foregroundColor(.blue).frame(width: 24, height: 24).background(Color.blue.opacity(0.1)).cornerRadius(6) } }.buttonStyle(PlainButtonStyle()).disabled(warpManager.isScanningProxy).help(settings.t(.btnScan)) } }.padding(12).background(DesignSystem.cardColor).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.strokeColor, lineWidth: 1)); VStack(spacing: 8) { HStack { Text(settings.t(.warpFormat)).font(.caption).foregroundColor(.secondary); Spacer(); Picker("", selection: $warpManager.selectedFormat) { ForEach(ExportFormat.allCases) { format in Text(format.rawValue).tag(format) } }.labelsHidden().frame(width: 140) }; HStack { TextField(settings.t(.endpointAuto), text: $warpManager.customEndpoint).textFieldStyle(RoundedBorderTextFieldStyle()).font(.system(size: 11, design: .monospaced)); Button(action: { showScannerSheet = true }) { Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(.blue) }.buttonStyle(PlainButtonStyle()).frame(width: 28, height: 28).background(Color.blue.opacity(0.1)).cornerRadius(6).help(settings.t(.endpointScanHelp)) } }.padding(8).background(DesignSystem.cardColor).cornerRadius(10); Button(action: { warpManager.generateConfig() }) { if warpManager.isGenerating { ProgressView().scaleEffect(0.5).frame(maxWidth: .infinity) } else { HStack { Image(systemName: "sparkles"); Text(settings.t(.btnGenerate)) }.font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white).frame(maxWidth: .infinity) } }.frame(height: 44).background(Color.purple).cornerRadius(12).shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3).buttonStyle(PlainButtonStyle()).disabled(warpManager.isGenerating); TextEditor(text: .constant(warpManager.generatedConfig)).font(.system(size: 10, design: .monospaced)).padding(6).background(Color(NSColor.textBackgroundColor).opacity(0.5)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.strokeColor, lineWidth: 1)).frame(maxHeight: .infinity); if !warpManager.generatedConfig.isEmpty { HStack(spacing: 12) { Button(action: { showQRCodeSheet = true }) { Label("QR", systemImage: "qrcode") }.buttonStyle(ModernButtonStyle(color: .gray)).disabled(warpManager.isConfigTooLargeForQR); if #available(macOS 13.0, *) { ShareLink(item: warpManager.generatedConfig) { Label(settings.t(.btnShare), systemImage: "square.and.arrow.up").font(.system(size: 11, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.blue).foregroundColor(.white).cornerRadius(8) }.buttonStyle(PlainButtonStyle()) } else { Button(action: { warpManager.copyToClipboard() }) { Label(settings.t(.btnCopy), systemImage: "doc.on.doc") }.buttonStyle(ModernButtonStyle(color: .blue)) }; Button(action: { warpManager.saveToFile() }) { Label(settings.t(.btnSaveFile), systemImage: "square.and.arrow.down") }.buttonStyle(ModernButtonStyle(color: .green)) }.frame(height: 32) }; if !warpManager.statusMessage.isEmpty { Text(warpManager.statusMessage).font(.caption).foregroundColor(.secondary) } }.onAppear { warpManager.detectProxy() }.sheet(isPresented: $showSettingsSheet) { WarpSettingsSheet(warpManager: warpManager) }.sheet(isPresented: $showQRCodeSheet) { QRCodeSheet(image: warpManager.qrCodeImage, configName: warpManager.selectedFormat.rawValue) }.sheet(isPresented: $showScannerSheet) { ScannerSheet() } }
}

// ModernTabButton deprecated - use UXUIKit.ModernTabBar

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
