import SwiftUI

// Перечисление вкладок для Tools (С иконками)
enum ToolTab: Int, CaseIterable, Identifiable {
    case traffic = 0
    case speedTest = 1
    case hostlist = 2
    case diagnostics = 3
    // case vpn = 4 // НОВЫЙ ТАБ
    
    var id: Int { rawValue }
    
    // Иконки для табов
    var icon: String {
        switch self {
        case .traffic: return "network"
        case .speedTest: return "speedometer"
        case .hostlist: return "list.bullet.rectangle.portrait"
        case .diagnostics: return "stethoscope"
        // case .vpn: return "lock.shield" // Иконка для VPN
        }
    }
    
    func helpText(settings: SettingsManager) -> String {
        switch self {
        case .traffic: return settings.t(.toolsTraffic)
        case .speedTest: return settings.t(.toolsSpeedTest)
        case .hostlist: return settings.t(.toolsHostlist)
        case .diagnostics: return settings.t(.diagTitle)
        // case .vpn: return "VPN" // Можно добавить локализацию
        }
    }
}

struct ToolsView: View {
    @ObservedObject var tools: ToolsManager
    @ObservedObject var settings: SettingsManager
    @State private var currentTab: ToolTab = .traffic
    
    // 1. Создаем Namespace
    @Namespace private var toolsAnimation
    
    var body: some View {
        VStack(spacing: 16) {
            // Навигация (Иконки вместо текста)
            HStack(spacing: 4) {
                ForEach(ToolTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { currentTab = tab }
                    }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(currentTab == tab ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                ZStack {
                                    if currentTab == tab {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue)
                                            // 2. Используем toolsAnimation вместо Namespace().wrappedValue
                                            .matchedGeometryEffect(id: "TOOL_TAB", in: toolsAnimation)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(tab.helpText(settings: settings))
                }
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.strokeColor, lineWidth: 1))
            .padding(.top, 4)
            
            // Контент
            Group {
                switch currentTab {
                case .traffic: TrafficLogView(tools: tools, settings: settings)
                case .speedTest: SpeedTestView(tools: tools, settings: settings)
                case .hostlist: HostlistEditorView(tools: tools, settings: settings)
                case .diagnostics: DiagnosticsView(tools: tools, settings: settings)
                // case .vpn: SSConnectionView() // НОВЫЙ ВЬЮ
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - HELPERS
struct PresetButton: View { let title: String; let icon: String; let color: Color; let action: () -> Void; var body: some View { Button(action: action) { HStack(spacing: 4) { Image(systemName: icon); Text(title) }.font(.system(size: 11, weight: .medium)).foregroundColor(.white).padding(.vertical, 6).frame(maxWidth: .infinity).background(color.opacity(0.8)).cornerRadius(8) }.buttonStyle(PlainButtonStyle()) } }
struct LineGraph: Shape { var data: [Double]; func path(in rect: CGRect) -> Path { var path = Path(); guard data.count > 1 else { return path }; let step = rect.width / CGFloat(data.count - 1); let maxVal = (data.max() ?? 100) * 1.2; let minVal = 0.0; for (index, value) in data.enumerated() { let x = CGFloat(index) * step; let y = rect.height - (CGFloat(value - minVal) / CGFloat(maxVal - minVal)) * rect.height; if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) } }; return path } }
