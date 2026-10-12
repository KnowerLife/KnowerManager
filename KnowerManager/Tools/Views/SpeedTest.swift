import SwiftUI

struct SpeedTestView: View {
    @ObservedObject var tools: ToolsManager
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.1), lineWidth: 15).frame(width: 140, height: 140)
                Circle().trim(from: 0, to: tools.isTestingSpeed ? 0.75 : 0)
                    .stroke(AngularGradient(colors: [.blue, .purple], center: .center), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .frame(width: 140, height: 140).rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 1.5), value: tools.isTestingSpeed)
                VStack(spacing: 4) {
                    Text(tools.downloadSpeed).font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("MB/s").font(.caption).foregroundColor(.secondary)
                }
            }.padding(.top, 10)
            
            HStack(spacing: 16) {
                PingCard(title: settings.t(.pingGoogle), ms: tools.pingGoogle)
                PingCard(title: settings.t(.pingCloudflare), ms: tools.pingCloudflare)
            }
            
            Button(action: { tools.runSpeedTest() }) {
                Text(tools.isTestingSpeed ? settings.t(.speedTesting) : settings.t(.speedRun)).font(.system(size: 14, weight: .semibold))
            }.buttonStyle(ModernButtonStyle(color: .blue)).disabled(tools.isTestingSpeed)
        }.padding(20).frame(maxWidth: .infinity).background(DesignSystem.cardColor).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.cardStroke, lineWidth: 1))
    }
}

struct PingCard: View { let title: String; let ms: Double; var body: some View { VStack { Text(title).font(.caption).bold().foregroundColor(.secondary); Text("\(Int(ms)) ms").font(.system(.body, design: .monospaced)) }.frame(maxWidth: .infinity).padding(8).background(Color.black.opacity(0.05)).cornerRadius(8) } }
