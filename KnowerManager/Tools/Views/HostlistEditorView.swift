import SwiftUI

struct HostlistEditorView: View {
    @ObservedObject var tools: ToolsManager
    @ObservedObject var settings: SettingsManager
    @State private var newDomain = ""
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack {
                    TextField(settings.t(.hostPlaceholder), text: $newDomain).textFieldStyle(PlainTextFieldStyle()).padding(8).background(DesignSystem.cardColor).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignSystem.cardStroke, lineWidth: 1)).onSubmit { addDomain() }
                    Button(action: addDomain) { Image(systemName: "plus").font(.title2).foregroundColor(.blue) }.buttonStyle(PlainButtonStyle())
                }
                HStack(spacing: 8) {
                    PresetButton(title: settings.t(.presetSocials), icon: "person.2.fill", color: .indigo) { tools.loadPreset("socials") }
                    PresetButton(title: settings.t(.presetMedia), icon: "play.tv.fill", color: .red) { tools.loadPreset("media") }
                    PresetButton(title: settings.t(.presetNews), icon: "newspaper.fill", color: .orange) { tools.loadPreset("news") }
                }
            }
            List {
                ForEach(tools.customDomains, id: \.self) { domain in
                    HStack { Text(domain).font(.system(size: 13, design: .monospaced)); Spacer(); Button(action: { if let idx = tools.customDomains.firstIndex(of: domain) { tools.customDomains.remove(at: idx) } }) { Image(systemName: "xmark").foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle()) }.listRowBackground(Color.clear)
                }
            }.listStyle(.plain).background(DesignSystem.cardColor.opacity(0.5)).cornerRadius(12)
            Button(settings.t(.hostSave)) { tools.saveHostlist() }.buttonStyle(ModernButtonStyle(color: .green))
        }
    }
    func addDomain() { guard !newDomain.isEmpty else { return }; if !tools.customDomains.contains(newDomain) { withAnimation { tools.customDomains.insert(newDomain, at: 0) } }; newDomain = "" }
}
