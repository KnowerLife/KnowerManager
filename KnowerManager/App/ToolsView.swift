import SwiftUI

// MARK: - Вкладка «Инструменты» (Сброс DNS, Монитор трафика, Ping, Проверка порта)
//
// Вёрстка рассчитана на узкое окно (DS.width = 380). Кнопки используют
// ModernButtonStyle (он растягивается на всю ширину), поэтому каждая кнопка
// стоит в отдельной строке — рядом с полями ввода они сжимали бы друг друга.

struct ToolsView: View {
    @ObservedObject var settings = SettingsManager.shared

    // DNS Flush
    @State private var dnsStatus: String?
    @State private var dnsFailed = false
    @State private var isFlushingDNS = false

    // Traffic
    @State private var trafficStats = NetworkTools.TrafficStats(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
    @State private var trafficTimer: Timer?

    // Ping
    @State private var pingHost = "google.com"
    @State private var pingResult: String?
    @State private var isPinging = false

    // Port check
    @State private var portHost = "google.com"
    @State private var portNumber = "443"
    @State private var portResult: PortCheckResult?
    @State private var isCheckingPort = false

    private struct PortCheckResult {
        let host: String
        let port: Int
        let isOpen: Bool
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                dnsFlushSection
                trafficSection
                pingSection
                portCheckSection
                Spacer().frame(height: 40)
            }
            .padding(12)
        }
        .onAppear { startTrafficTimer() }
        .onDisappear { stopTrafficTimer() }
    }

    // MARK: - DNS Flush

    private var dnsFlushSection: some View {
        card(title: settings.t(.toolsDNSTitle), icon: "arrow.clockwise.circle.fill", color: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                description(settings.t(.toolsDNSDesc))

                Button {
                    flushDNS()
                } label: {
                    Text(settings.t(.toolsFlushDNS))
                }
                .buttonStyle(ModernButtonStyle(color: .blue))
                .disabled(isFlushingDNS)

                if isFlushingDNS {
                    loadingRow
                } else if let status = dnsStatus {
                    statusBanner(status, ok: !dnsFailed)
                }
            }
        }
    }

    private func flushDNS() {
        dnsStatus = nil
        dnsFailed = false
        isFlushingDNS = true
        // Сброс кэша требует прав администратора: dscacheutil и сброс mDNSResponder
        // выполняются привилегированно (пароль спрашивается один раз и кэшируется).
        PrivilegedRunner.shared.runAsAdmin(script: NetworkTools.dnsFlushScript) { ok, message in
            isFlushingDNS = false
            dnsFailed = !ok
            if ok {
                dnsStatus = settings.t(.toolsFlushDNSResult)
            } else {
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                dnsStatus = trimmed.isEmpty ? settings.t(.toolsFlushDNSFailed) : trimmed
            }
        }
    }

    // MARK: - Traffic Monitor

    private var trafficSection: some View {
        card(title: settings.t(.toolsTrafficTitle), icon: "arrow.up.arrow.down.circle.fill", color: .green) {
            VStack(alignment: .leading, spacing: 10) {
                description(settings.t(.toolsTrafficDesc))

                HStack(spacing: 8) {
                    trafficTile(icon: "arrow.down", label: settings.t(.toolsTrafficIn),
                                bytes: trafficStats.bytesIn, color: .blue)
                    trafficTile(icon: "arrow.up", label: settings.t(.toolsTrafficOut),
                                bytes: trafficStats.bytesOut, color: .orange)
                }
            }
        }
    }

    private func trafficTile(icon: String, label: String, bytes: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(formatBytes(bytes))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func startTrafficTimer() {
        refreshTraffic()
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            refreshTraffic()
        }
    }

    private func stopTrafficTimer() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }

    private func refreshTraffic() {
        trafficStats = NetworkTools.getTrafficStats()
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb < 1 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.2f GB", mb / 1024)
        }
    }

    // MARK: - Ping

    private var pingSection: some View {
        card(title: settings.t(.toolsPingTitle), icon: "antenna.radiowaves.left.and.right", color: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                description(settings.t(.toolsPingDesc))

                TextField(settings.t(.toolsPingHost), text: $pingHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { if !isPinging { runPing() } }

                Button {
                    runPing()
                } label: {
                    Text(settings.t(.toolsPingButton))
                }
                .buttonStyle(ModernButtonStyle(color: .purple))
                .disabled(isPinging || pingHost.isEmpty)

                if isPinging {
                    loadingRow
                } else if let result = pingResult {
                    outputBox(result)
                }
            }
        }
    }

    private func runPing() {
        guard !pingHost.isEmpty else { return }
        isPinging = true
        pingResult = nil
        let host = pingHost
        Task {
            let output = await NetworkTools.ping(host: host)
            await MainActor.run {
                isPinging = false
                pingResult = output
            }
        }
    }

    // MARK: - Port Check

    private var portCheckSection: some View {
        card(title: settings.t(.toolsPortTitle), icon: "network", color: .orange) {
            VStack(alignment: .leading, spacing: 10) {
                description(settings.t(.toolsPortDesc))

                HStack(spacing: 8) {
                    TextField(settings.t(.toolsPortHost), text: $portHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .onSubmit { if !isCheckingPort { checkPort() } }

                    TextField(settings.t(.toolsPortPort), text: $portNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 66)
                        .onSubmit { if !isCheckingPort { checkPort() } }
                }

                Button {
                    checkPort()
                } label: {
                    Text(settings.t(.toolsPortButton))
                }
                .buttonStyle(ModernButtonStyle(color: .orange))
                .disabled(isCheckingPort || portHost.isEmpty || portNumber.isEmpty)

                if isCheckingPort {
                    loadingRow
                } else if let result = portResult {
                    let state = result.isOpen ? settings.t(.toolsPortOpen) : settings.t(.toolsPortClosed)
                    statusBanner("\(result.host):\(result.port) — \(state)", ok: result.isOpen)
                }
            }
        }
    }

    private func checkPort() {
        guard !portHost.isEmpty, let port = Int(portNumber) else { return }
        isCheckingPort = true
        portResult = nil
        let host = portHost
        Task {
            let isOpen = await NetworkTools.checkPort(host: host, port: port)
            await MainActor.run {
                isCheckingPort = false
                portResult = PortCheckResult(host: host, port: port, isOpen: isOpen)
            }
        }
    }

    // MARK: - Components

    private func card<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppThemeTokens.Surface.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppThemeTokens.Border.normal, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func description(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBanner(_ text: String, ok: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(ok ? .green : .red)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outputBox(_ text: String) -> some View {
        ScrollView {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 130)
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppThemeTokens.Border.subtle, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
