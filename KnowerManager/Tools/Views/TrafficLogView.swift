import SwiftUI

struct TrafficLogView: View {
    @ObservedObject var tools: ToolsManager
    @ObservedObject var settings: SettingsManager
    @State private var newHost = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(settings.t(.toolsTraffic), systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                Spacer()
                // Кнопки управления
                Button(action: { tools.refreshAll() }) { Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .bold)) }.buttonStyle(PlainButtonStyle())
                Button(action: { tools.clearAllTargets() }) { Image(systemName: "trash").font(.system(size: 12)) }.buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            // Input
            HStack {
                TextField(settings.t(.toolsAddTargetPlh), text: $newHost)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(6).background(Color.black.opacity(0.05)).cornerRadius(6)
                    .onSubmit { if !newHost.isEmpty { tools.addTarget(newHost); newHost = "" } }
                Button { if !newHost.isEmpty { tools.addTarget(newHost); newHost = "" } } label: { Image(systemName: "plus") }.buttonStyle(PlainButtonStyle())
            }
            
            // List
            if tools.pingTargets.isEmpty {
                Text(settings.t(.toolsNoMonitors)).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity).padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(tools.pingTargets) { target in
                            HStack {
                                Image(systemName: "server.rack").font(.system(size: 10)).foregroundColor(.secondary)
                                Text(target.host).font(.system(size: 12, weight: .medium, design: .monospaced))
                                Spacer()
                                Text("\(target.currentPing) ms").font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(target.currentPing < 100 ? .green : (target.currentPing < 200 ? .orange : .red))
                                Button { tools.removeTarget(id: target.id) } label: { Image(systemName: "xmark").font(.caption) }.buttonStyle(PlainButtonStyle())
                            }.padding(8).background(Color.black.opacity(0.05)).cornerRadius(8)
                        }
                    }
                }.frame(maxHeight: 200)
                
                // Graph (Common for all)
                if !tools.pingTargets.isEmpty {
                    let data = tools.pingTargets.map { Double($0.currentPing) }
                    LineGraph(data: data).stroke(Color.green, lineWidth: 2).frame(height: 40).background(Color.black.opacity(0.02)).cornerRadius(8).padding(.top, 4)
                }
            }
        }
        .padding(16).background(DesignSystem.cardColor).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.cardStroke, lineWidth: 1))
    }
}
