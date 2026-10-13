import SwiftUI

// MARK: - Вкладка «Инструменты» (DNS Flush, Монитор трафика, Ping, Проверка порта)

struct ToolsView: View {
    @ObservedObject var settings = SettingsManager.shared

    // DNS Flush
    @State private var dnsStatus: String?
    @State private var dnsFailed = false

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
    @State private var portResult: String?
    @State private var isCheckingPort = false

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
        card(title: settings.t(.toolsDNSTitle), icon: "arrow.clockwise.circle", color: .blue) {
            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t(.toolsDNSDesc))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button(settings.t(.toolsFlushDNS)) {
                        flushDNS()
                    }
                    .buttonStyle(ModernButtonStyle(color: .blue))

                    if let status = dnsStatus {
                        Label(status, systemImage: dnsFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(dnsFailed ? .red : .green)
                    }
                }
            }
        }
    }

    private func flushDNS() {
        dnsStatus = nil
        dnsFailed = false
        let result = NetworkTools.flushDNS()
        switch result {
        case .success:
            dnsFailed = false
            dnsStatus = settings.t(.toolsFlushDNSResult)
        case .failure(let error):
            dnsFailed = true
            dnsStatus = error.localizedDescription
        }
    }

    // MARK: - Traffic Monitor

    private var trafficSection: some View {
        card(title: settings.t(.toolsTrafficTitle), icon: "arrow.up.arrow.down.circle", color: .green) {
            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t(.toolsTrafficDesc))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    trafficItem(label: settings.t(.toolsTrafficIn), bytes: trafficStats.bytesIn, color: .blue)
                    trafficItem(label: settings.t(.toolsTrafficOut), bytes: trafficStats.bytesOut, color: .orange)
                }
            }
        }
    }

    private func trafficItem(label: String, bytes: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatBytes(bytes))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
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
            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t(.toolsPingDesc))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField(settings.t(.toolsPingHost), text: $pingHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button(settings.t(.toolsPingButton)) {
                        runPing()
                    }
                    .buttonStyle(ModernButtonStyle(color: .purple))
                    .disabled(isPinging || pingHost.isEmpty)
                }

                if isPinging {
                    HStack {
                        ProgressView().controlSize(.mini)
                        Text("...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let result = pingResult {
                    Text(result)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        card(title: settings.t(.toolsPortTitle), icon: "network.badge.shield.half.filled", color: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t(.toolsPortDesc))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField(settings.t(.toolsPortHost), text: $portHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 160)

                    TextField(settings.t(.toolsPortPort), text: $portNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 60)

                    Button(settings.t(.toolsPortButton)) {
                        checkPort()
                    }
                    .buttonStyle(ModernButtonStyle(color: .orange))
                    .disabled(isCheckingPort || portHost.isEmpty || portNumber.isEmpty)
                }

                if isCheckingPort {
                    HStack {
                        ProgressView().controlSize(.mini)
                        Text("...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let result = portResult {
                    Text(result)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                portResult = isOpen ? "✓ \(host):\(port) — OPEN" : "✗ \(host):\(port) — CLOSED"
            }
        }
    }

    // MARK: - Card wrapper

    private func card<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppThemeTokens.Surface.elevated)
        .cornerRadius(12)
    }
}
