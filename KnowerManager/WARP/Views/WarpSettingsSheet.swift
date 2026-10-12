import SwiftUI

struct WarpSettingsSheet: View {
    @ObservedObject var warpManager: WarpManager
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(settings.t(.warpGenSettings)).font(.headline); Spacer(); Button(settings.t(.btnDone)) { dismiss() }.buttonStyle(PlainButtonStyle()).foregroundColor(.blue) }.padding().background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            ScrollView {
                VStack(spacing: 20) {
                    // Method & SSH
                    SectionCard(title: settings.t(.warpMethod), icon: "server.rack") {
                        Picker("", selection: $warpManager.generationMethod) { Text(settings.t(.methodLocal)).tag(GenerationMethod.local); Text(settings.t(.methodSSH)).tag(GenerationMethod.ssh) }.pickerStyle(SegmentedPickerStyle()).labelsHidden()
                        if warpManager.generationMethod == .ssh {
                            VStack(spacing: 12) {
                                Divider()
                                SettingsTextField(icon: "network", placeholder: "192.168.1.1", text: $warpManager.sshHost, title: settings.t(.sshHost))
                                HStack { SettingsTextField(icon: "person", placeholder: "root", text: $warpManager.sshUser, title: settings.t(.sshUser)); SettingsTextField(icon: "number", placeholder: "22", text: $warpManager.sshPort, title: settings.t(.sshPort)).frame(width: 80) }
                                SettingsTextField(icon: "key", placeholder: "******", text: $warpManager.sshPassword, title: settings.t(.sshPass), isSecure: true)
                            }.padding(.top, 8)
                        }
                    }
                    
                    // Amnezia Params
                    SectionCard(title: settings.t(.warpParams), icon: "slider.horizontal.3") {
                        HStack(spacing: 16) { ParamField(label: "Jc", value: $warpManager.amneziaParams.jc); ParamField(label: "Jmin", value: $warpManager.amneziaParams.jmin); ParamField(label: "Jmax", value: $warpManager.amneziaParams.jmax) }
                        Divider()
                        HStack { ParamField(label: "S1", value: $warpManager.amneziaParams.s1); ParamField(label: "S2", value: $warpManager.amneziaParams.s2); Spacer() }
                    }
                    
                    // Routing
                    SectionCard(title: settings.t(.warpRouting), icon: "arrow.triangle.branch") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(RoutingRule.allCases) { rule in
                                ToggleRow(title: rule.rawValue, isOn: binding(for: rule))
                            }
                        }
                    }
                }.padding()
            }
        }.frame(width: 380, height: 600)
    }
    
    private func binding(for rule: RoutingRule) -> Binding<Bool> { Binding(get: { warpManager.selectedRoutingRules.contains(rule) }, set: { if $0 { warpManager.selectedRoutingRules.insert(rule) } else { warpManager.selectedRoutingRules.remove(rule) } }) }
}

struct SectionCard<Content: View>: View { let title: String; let icon: String; let content: Content; init(title: String, icon: String, @ViewBuilder content: () -> Content) { self.title = title; self.icon = icon; self.content = content() }; var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Image(systemName: icon).foregroundColor(.blue); Text(title).font(.system(size: 13, weight: .semibold)) }; content }.padding().background(Color(NSColor.controlBackgroundColor).opacity(0.6)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)) } }
struct SettingsTextField: View { let icon: String; let placeholder: String; @Binding var text: String; let title: String; var isSecure: Bool = false; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundColor(.secondary); HStack { Image(systemName: icon).foregroundColor(.secondary).font(.caption); if isSecure { SecureField(placeholder, text: $text).textFieldStyle(PlainTextFieldStyle()) } else { TextField(placeholder, text: $text).textFieldStyle(PlainTextFieldStyle()) } }.padding(6).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1)) } } }
struct ParamField: View { let label: String; @Binding var value: Int; private static let formatter: NumberFormatter = { let f = NumberFormatter(); f.numberStyle = .none; f.allowsFloats = false; return f }(); var body: some View { VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption).foregroundColor(.secondary); TextField("", value: $value, formatter: Self.formatter).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 60) } } }
struct ToggleRow: View { let title: String; @Binding var isOn: Bool; var body: some View { Toggle(isOn: $isOn) { Text(title).font(.system(size: 13)) }.toggleStyle(SwitchToggleStyle(tint: .blue)) } }
