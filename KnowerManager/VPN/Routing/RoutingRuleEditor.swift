import SwiftUI

/// Редактор одного правила маршрутизации (поля соответствуют Xray routing rule).
/// Встраивается прямо в окно маршрутизации. Компактная вёрстка: помещается
/// в невысокое окно, при нехватке места прокручивается.
struct RoutingRuleEditor: View {
    @ObservedObject var settings = SettingsManager.shared

    @State private var draft: VPNRoutingRule
    @State private var name: String
    @State private var domainText: String
    @State private var ipText: String
    @State private var portText: String
    @State private var protocols: Set<String>
    @State private var network: String     // "", "tcp", "udp", "tcp,udp"

    let onSave: (VPNRoutingRule) -> Void
    let onCancel: () -> Void

    private let protocolOptions = ["http", "tls", "quic", "bittorrent"]

    init(rule: VPNRoutingRule,
         onSave: @escaping (VPNRoutingRule) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: rule)
        _name = State(initialValue: rule.name)
        _domainText = State(initialValue: (rule.domain ?? []).joined(separator: "\n"))
        _ipText = State(initialValue: (rule.ip ?? []).joined(separator: "\n"))
        _portText = State(initialValue: rule.port ?? "")
        _protocols = State(initialValue: Set(rule.protocolType ?? []))
        _network = State(initialValue: rule.network ?? "")
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isNew: Bool {
        !RoutingManager.shared.rules.contains { $0.id == draft.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    basicSection
                    conditionsSection
                }
                .padding(12)
            }

            Divider()
            buttons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            Text(isNew ? settings.t(.routingRuleNew) : settings.t(.routingRuleEdit))
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: $draft.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(settings.t(.routingEnabled))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Basic

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(settings.t(.sectionGeneral))

            labeled(settings.t(.labelName)) {
                TextField(settings.t(.routingRuleNew), text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            labeled(settings.t(.routingAction)) {
                Picker("", selection: $draft.outboundTag) {
                    Text(settings.t(.routingOutProxy)).tag(RoutingOutbound.proxy.rawValue)
                    Text(settings.t(.routingOutDirect)).tag(RoutingOutbound.direct.rawValue)
                    Text(settings.t(.routingOutBlock)).tag(RoutingOutbound.block.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(card)
    }

    // MARK: - Conditions

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(settings.t(.routingConditions))

            labeled(settings.t(.routingFieldNetwork)) {
                Picker("", selection: $network) {
                    Text(settings.t(.routingNetworkAny)).tag("")
                    Text("TCP").tag("tcp")
                    Text("UDP").tag("udp")
                    Text("TCP+UDP").tag("tcp,udp")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            labeled(settings.t(.routingFieldDomains)) {
                editorBox(text: $domainText, height: 40,
                          placeholder: "geosite:google, domain:example.com")
                    .help(settings.t(.routingHintDomains))
            }

            labeled(settings.t(.routingFieldIPs)) {
                editorBox(text: $ipText, height: 36,
                          placeholder: "geoip:private, 192.168.0.0/16")
                    .help(settings.t(.routingHintIPs))
            }

            labeled(settings.t(.routingFieldPorts)) {
                TextField("80,443 или 1000-2000", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .help(settings.t(.routingHintPorts))
            }

            labeled(settings.t(.routingFieldProtocols)) {
                HStack(spacing: 6) {
                    ForEach(protocolOptions, id: \.self) { option in
                        protocolChip(option)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(card)
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack {
            Button(settings.t(.btnCancel), action: onCancel)
            Spacer()
            Button(settings.t(.btnSave)) { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Building blocks

    private var card: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
    }

    private func labeled<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            content()
        }
    }

    /// Текстовое поле для списка (домены/IP) с плейсхолдером.
    private func editorBox(text: Binding<String>,
                           height: CGFloat,
                           placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: height)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
            }
        }
    }

    private func protocolChip(_ option: String) -> some View {
        let selected = protocols.contains(option)
        return Button {
            if selected { protocols.remove(option) } else { protocols.insert(option) }
        } label: {
            Text(option.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selected ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.12))
                .foregroundColor(selected ? .blue : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        var rule = draft
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.name = trimmed.isEmpty ? settings.t(.routingRuleNew) : trimmed
        rule.type = "field"
        rule.domain = Self.parseList(domainText)
        rule.ip = Self.parseList(ipText)
        rule.port = Self.parsePorts(portText)
        rule.protocolType = protocols.isEmpty
            ? nil
            : protocolOptions.filter { protocols.contains($0) }
        rule.network = network.isEmpty ? nil : network
        onSave(rule)
    }

    /// Разбивает ввод по строкам/запятым/точкам с запятой, убирает пустые значения.
    private static func parseList(_ text: String) -> [String]? {
        let items = text
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    /// Нормализует список портов в формат Xray: "80,443" или "1000-2000".
    private static func parsePorts(_ text: String) -> String? {
        let items = text
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" || $0 == " " || $0 == "\t" })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return items.isEmpty ? nil : items.joined(separator: ",")
    }
}
