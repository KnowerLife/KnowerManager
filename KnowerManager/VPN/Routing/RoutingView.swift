import SwiftUI

struct RoutingView: View {
    @ObservedObject var manager = RoutingManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(settings.t(.routingTitle)) // "Настройки маршрутизации"
                    .font(.headline)
                Spacer()
                Button(settings.t(.btnCancel)) { // Можно заменить на "Done" или "Закрыть", если есть ключ
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Form {
                // 1. Выбор режима
                Section {
                    Picker("Mode", selection: $manager.mode) {
                        ForEach(VPNRoutingMode.allCases, id: \.self) { mode in
                            Text(modeName(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                    
                    Text(modeDescription(manager.mode))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text(settings.t(.routingMode)) // "Режим работы"
                }
                
                // 2. Правила (Только если выбран режим Rules)
                if manager.mode == .rules {
                    Section(header: Text(settings.t(.routingRulesHeader))) { // "Правила..."
                        List {
                            ForEach($manager.rules) { $rule in
                                HStack {
                                    Toggle(isOn: $rule.enabled) {
                                        VStack(alignment: .leading) {
                                            Text(rule.name)
                                                .font(.system(size: 13, weight: .medium))
                                            HStack(spacing: 4) {
                                                tagView(rule.outboundTag)
                                                Text(ruleDetail(rule))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                }
                                .padding(.vertical, 4)
                            }
                            .onMove { indices, newOffset in
                                manager.rules.move(fromOffsets: indices, toOffset: newOffset)
                            }
                        }
                        .frame(minHeight: 200)
                    }
                    
                    HStack {
                        Button(settings.t(.routingReset)) { // "Сбросить по умолчанию"
                            manager.loadDefaults()
                        }
                        .font(.caption)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
    
    // Перевод названий режимов
    func modeName(_ mode: VPNRoutingMode) -> String {
        switch mode {
        case .global: return settings.t(.routeGlobal)
        case .direct: return settings.t(.routeDirect)
        case .rules: return settings.t(.routeRules)
        }
    }
    
    // Перевод описаний
    func modeDescription(_ mode: VPNRoutingMode) -> String {
        switch mode {
        case .global: return settings.t(.routingDescGlobal)
        case .direct: return settings.t(.routingDescDirect)
        case .rules: return settings.t(.routingDescRules)
        }
    }
    
    func ruleDetail(_ rule: VPNRoutingRule) -> String {
        if let d = rule.domain { return "Domains: \(d.joined(separator: ", "))" }
        if let i = rule.ip { return "IPs: \(i.joined(separator: ", "))" }
        return "Protocol: \(rule.protocolType?.joined(separator: ", ") ?? "All")"
    }
    
    func tagView(_ tag: String) -> some View {
        Text(tag.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(colorForTag(tag).opacity(0.2))
            .foregroundColor(colorForTag(tag))
            .cornerRadius(4)
    }
    
    func colorForTag(_ tag: String) -> Color {
        switch tag {
        case "proxy": return .blue
        case "direct": return .green
        case "block": return .red
        default: return .gray
        }
    }
}
