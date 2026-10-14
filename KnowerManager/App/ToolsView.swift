import SwiftUI

struct ToolsView: View {
    @ObservedObject var store = ToolStore.shared
    @ObservedObject var settings = SettingsManager.shared
    
    // Network Info
    @State private var networkInfo = NetworkInfoProvider.getActiveInterface()
    @State private var networkExpanded = false
    
    // Keep Awake
    var keepAwakeTool: Tool? { store.tools.first(where: { $0.id == "keepAwake" }) }
    
    // DNS Lookup
    @State private var dnsDomain = ""
    @State private var dnsResult: String?
    @State private var isDnsLoading = false
    
    // ARP Flush
    @State private var showArpAlert = false
    @State private var arpStatus: String?
    @State private var arpFailed = false
    @State private var isArpFlushing = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(store.tools) { tool in
                    switch tool.type {
                    case .info:
                        networkInfoSection(tool: tool)
                    case .toggle:
                        toggleSection(tool: tool)
                    case .action:
                        actionSection(tool: tool)
                    }
                }
                Spacer().frame(height: 40)
            }
            .padding(12)
        }
        .frame(width: DesignSystem.width, alignment: .leading)
        .onAppear {
            networkInfo = NetworkInfoProvider.getActiveInterface()
        }
    }
    
    private func networkInfoSection(tool: Tool) -> some View {
        card(title: settings.t(tool.titleKey), icon: "info.circle.fill", color: .blue) {
            VStack(alignment: .leading, spacing: 8) {
                if let desc = tool.descKey {
                    description(settings.t(desc))
                }
                DisclosureGroup(isExpanded: $networkExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        infoRow(title: settings.t(.toolInterface), value: networkInfo.name)
                        infoRow(title: settings.t(.toolIpv4), value: networkInfo.ipv4)
                        infoRow(title: settings.t(.toolIpv6), value: networkInfo.ipv6)
                        infoRow(title: settings.t(.toolMac), value: networkInfo.mac)
                        infoRow(title: settings.t(.toolGateway), value: networkInfo.gateway)
                        infoRow(title: settings.t(.toolDns), value: networkInfo.dns)
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 6) {
                        Text(networkExpanded ? settings.t(.btnHide) : settings.t(.btnShow))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            networkInfo = NetworkInfoProvider.getActiveInterface()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .help(settings.t(.btnRefresh))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .font(.caption)
            }
        }
    }
    
    private func toggleSection(tool: Tool) -> some View {
        card(title: settings.t(tool.titleKey), icon: "power.circle.fill", color: .green) {
            VStack(alignment: .leading, spacing: 10) {
                if let desc = tool.descKey {
                    description(settings.t(desc))
                }
                HStack(alignment: .center, spacing: 8) {
                    Text(settings.t(.toolEnabled))
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { tool.enabled },
                        set: { store.saveEnabled(tool.id, $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .fixedSize()
                }
                HStack(alignment: .center, spacing: 8) {
                    Text(settings.t(.toolShowInMini))
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { tool.showInMiniMenu },
                        set: { store.saveShowInMini(tool.id, $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .fixedSize()
                }
                if tool.id == "keepAwake" && tool.enabled {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.green)
                        Text(settings.t(.toolKeepAwakeActive))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private func actionSection(tool: Tool) -> some View {
        if tool.id == "dnsLookup" {
            return AnyView(dnsLookupSection(tool: tool))
        } else if tool.id == "arpFlush" {
            return AnyView(arpFlushSection(tool: tool))
        }
        return AnyView(EmptyView())
    }
    
    private func dnsLookupSection(tool: Tool) -> some View {
        card(title: settings.t(tool.titleKey), icon: "magnifyingglass.circle.fill", color: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                if let desc = tool.descKey {
                    description(settings.t(desc))
                }
                TextField("example.com", text: $dnsDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                Button {
                    runDnsLookup()
                } label: {
                    Text(settings.t(.toolDnsLookupCheck))
                }
                .buttonStyle(ModernButtonStyle(color: .purple))
                .disabled(isDnsLoading || dnsDomain.isEmpty)
                if isDnsLoading {
                    loadingRow
                } else if let result = dnsResult {
                    outputBox(result)
                }
            }
        }
    }
    
    private func runDnsLookup() {
        guard !dnsDomain.isEmpty else { return }
        isDnsLoading = true
        dnsResult = nil
        let host = dnsDomain
        Task {
            let output = await NetworkTools.dnsLookup(host: host)
            await MainActor.run {
                isDnsLoading = false
                dnsResult = output
            }
        }
    }
    
    private func arpFlushSection(tool: Tool) -> some View {
        card(title: settings.t(tool.titleKey), icon: "bolt.circle.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 10) {
                if let desc = tool.descKey {
                    description(settings.t(desc))
                }
                Button {
                    showArpAlert = true
                } label: {
                    Text(settings.t(.toolArpFlushTitle))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(ModernButtonStyle(color: .orange, variant: .outline))
                .disabled(isArpFlushing)
                if isArpFlushing {
                    loadingRow
                } else if let status = arpStatus {
                    statusBanner(status, ok: !arpFailed)
                }
            }
        }
        .alert(settings.t(.toolArpFlushConfirmTitle), isPresented: $showArpAlert) {
            Button(settings.t(.btnCancel), role: .cancel) {}
            Button(settings.t(.btnOK), role: .destructive) {
                flushArp()
            }
        } message: {
            Text(settings.t(.toolArpFlushConfirm))
        }
    }
    
    private func flushArp() {
        arpStatus = nil
        arpFailed = false
        isArpFlushing = true
        ArpFlushRunner.flush { ok, message in
            isArpFlushing = false
            arpFailed = !ok
            if ok {
                arpStatus = settings.t(.toolArpFlushSuccess)
            } else {
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                arpStatus = trimmed.isEmpty ? settings.t(.toolArpFlushFailed) : trimmed
            }
        }
    }
    
    // Reuse components
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
                    .lineLimit(1)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppThemeTokens.Surface.elevated)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppThemeTokens.Border.normal, lineWidth: 1))
        .cornerRadius(12)
    }
    
    private func description(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var loadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("...").font(.caption).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func statusBanner(_ text: String, ok: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppThemeTokens.Border.subtle, lineWidth: 1))
        .cornerRadius(8)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(alignment: .leading)
            Spacer(minLength: 12)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
