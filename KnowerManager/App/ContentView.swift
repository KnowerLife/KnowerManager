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
                        // --- ТАБ 1: OCR (Сканер) ---
                        ScannerView(ocrManager: ocrManager, settings: settings)
                            .padding(.horizontal, 18).transition(.opacity)
                    } else {
                        // --- ТАБ 2: Инструменты ---
                        ToolsView()
                            .padding(.horizontal, 18).transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 22)
        }
        .frame(maxWidth: DesignSystem.width)
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
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.tabOcr), icon: "text.viewfinder", badge: nil),
                UXUIKit.ModernTabBar.TabItem(title: settings.t(.toolsTitle), icon: "wrench.and.screwdriver", badge: nil)
            ]
            UXUIKit.ModernTabBar(selectedTab: $selectedTab, tabs: tabs, namespace: animation)
        }
        .frame(width: DesignSystem.width)
    }
}

// Legacy button styles removed - use Design components
struct VisualEffectView: NSViewRepresentable { let material: NSVisualEffectView.Material; let blendingMode: NSVisualEffectView.BlendingMode; func makeNSView(context: Context) -> NSVisualEffectView { let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = .active; return v }; func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.material = material; nsView.blendingMode = blendingMode } }
struct WindowAccessor: NSViewRepresentable { var callback: (NSWindow) -> Void; func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { [weak view] in if let w = view?.window { self.callback(w) } }; return view }; func updateNSView(_ nsView: NSView, context: Context) {} }
struct RoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: RectCorner = .allCorners; func path(in rect: CGRect) -> Path { var path = Path(); let r = min(min(radius, rect.height/2), rect.width/2); let p1 = CGPoint(x: rect.minX, y: rect.minY); let p2 = CGPoint(x: rect.maxX, y: rect.minY); let p3 = CGPoint(x: rect.maxX, y: rect.maxY); let p4 = CGPoint(x: rect.minX, y: rect.maxY); if corners.contains(.topLeft) { path.move(to: CGPoint(x: p1.x, y: p1.y + r)); path.addArc(center: CGPoint(x: p1.x + r, y: p1.y + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) } else { path.move(to: p1) }; if corners.contains(.topRight) { path.addLine(to: CGPoint(x: p2.x - r, y: p2.y)); path.addArc(center: CGPoint(x: p2.x - r, y: p2.y + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false) } else { path.addLine(to: p2) }; if corners.contains(.bottomRight) { path.addLine(to: CGPoint(x: p3.x, y: p3.y - r)); path.addArc(center: CGPoint(x: p3.x - r, y: p3.y - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) } else { path.addLine(to: p3) }; if corners.contains(.bottomLeft) { path.addLine(to: CGPoint(x: p4.x + r, y: p4.y)); path.addArc(center: CGPoint(x: p4.x + r, y: p4.y - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) } else { path.addLine(to: p4) }; path.closeSubpath(); return path } }
struct RectCorner: Sendable, ExpressibleByArrayLiteral, Equatable { let rawValue: Int; init(rawValue: Int) { self.rawValue = rawValue }; init(arrayLiteral elements: RectCorner...) { var raw = 0; for element in elements { raw |= element.rawValue }; self.rawValue = raw }; func contains(_ member: RectCorner) -> Bool { return (rawValue & member.rawValue) != 0 }; static let topLeft = RectCorner(rawValue: 1 << 0); static let topRight = RectCorner(rawValue: 1 << 1); static let bottomLeft = RectCorner(rawValue: 1 << 2); static let bottomRight = RectCorner(rawValue: 1 << 3); static let allCorners = RectCorner(rawValue: 15) }
