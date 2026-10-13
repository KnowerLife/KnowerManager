import SwiftUI
import AppKit

/// Окно настройки маршрутизации (аналог Xray routing / Happ).
/// Режим работы + список правил с возможностью добавления, редактирования,
/// удаления, дублирования и изменения порядка.
struct RoutingView: View {
    @ObservedObject var manager = RoutingManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode

    /// Правило, открытое в редакторе. Если его нет в списке — значит новое.
    @State private var editingRule: VPNRoutingRule?

    var body: some View {
        VStack(spacing: 0) {
            if let rule = editingRule {
                RoutingRuleEditor(
                    rule: rule,
                    onSave: { saved in
                        manager.update(saved)
                        editingRule = nil
                    },
                    onCancel: { editingRule = nil }
                )
                .id(rule.id)
            } else {
                listContent
            }
        }
        .frame(width: 380)
        .frame(height: sheetHeight)
    }

    /// Высота окна: подстраивается под доступную высоту экрана, чтобы окно
    /// гарантированно помещалось и ничего не обрезалось (при нехватке места
    /// содержимое редактора прокручивается).
    private var sheetHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 800
        return min(620, max(400, visible - 180))
    }

    // MARK: - List

    private var listContent: some View {
        VStack(spacing: 0) {
            header
            Divider()

            List {
                modeSection

                if manager.mode == .rules {
                    rulesSection
                }
            }
            .listStyle(.inset)

            if manager.mode == .rules {
                Divider()
                footer
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            Text(settings.t(.routingTitle))
                .font(.headline)
            Spacer()
            Button(settings.t(.btnDone)) {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Mode

    private var modeSection: some View {
        Section {
            Picker(settings.t(.routingMode), selection: $manager.mode) {
                ForEach(VPNRoutingMode.allCases) { mode in
                    Text(modeName(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.vertical, 4)

            Text(modeDescription(manager.mode))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(settings.t(.routingMode))
        }
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section {
            if manager.rules.isEmpty {
                Text(settings.t(.routingEmptyRules))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach($manager.rules) { $rule in
                    RoutingRuleRow(
                        rule: $rule,
                        onEdit: { editingRule = rule },
                        onDuplicate: { manager.duplicateRule(id: rule.id) },
                        onDelete: { manager.deleteRule(id: rule.id) }
                    )
                }
                .onMove { manager.moveRule(from: $0, to: $1) }
                .onDelete { manager.rules.remove(atOffsets: $0) }
            }
        } header: {
            Text(settings.t(.routingRulesHeader))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                editingRule = manager.makeRule()
            } label: {
                Label(settings.t(.routingRuleAdd), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()

            Button(settings.t(.routingReset)) {
                manager.loadDefaults()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Helpers

    private func modeName(_ mode: VPNRoutingMode) -> String {
        switch mode {
        case .global: return settings.t(.routeGlobal)
        case .direct: return settings.t(.routeDirect)
        case .rules: return settings.t(.routeRules)
        }
    }

    private func modeDescription(_ mode: VPNRoutingMode) -> String {
        switch mode {
        case .global: return settings.t(.routingDescGlobal)
        case .direct: return settings.t(.routingDescDirect)
        case .rules: return settings.t(.routingDescRules)
        }
    }
}

// MARK: - Rule row

private struct RoutingRuleRow: View {
    @Binding var rule: VPNRoutingRule
    @ObservedObject var settings = SettingsManager.shared

    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name.isEmpty ? settings.t(.routingRuleNew) : rule.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    RoutingTagView(tag: rule.outboundTag)
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(rule.hasConditions ? .secondary : .orange)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer(minLength: 4)

            Button(action: onEdit) {
                Image(systemName: "pencil").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(settings.t(.routingRuleEdit))

            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red.opacity(0.85))
            .help(settings.t(.btnDelete))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(settings.t(.routingRuleEdit), action: onEdit)
            Button(settings.t(.btnDuplicate), action: onDuplicate)
            Divider()
            Button(settings.t(.btnDelete), role: .destructive, action: onDelete)
        }
    }

    /// Краткое описание условий правила для строки списка.
    private var summary: String {
        var parts: [String] = []
        if let d = rule.domain, !d.isEmpty { parts.append(d.joined(separator: ", ")) }
        if let i = rule.ip, !i.isEmpty { parts.append(i.joined(separator: ", ")) }
        if let p = rule.port, !p.isEmpty { parts.append("#\(p)") }
        if let pt = rule.protocolType, !pt.isEmpty { parts.append(pt.joined(separator: ", ")) }
        if let n = rule.network, !n.isEmpty { parts.append(n.uppercased()) }
        return parts.isEmpty ? settings.t(.detailAll) : parts.joined(separator: " · ")
    }
}

// MARK: - Outbound tag

private struct RoutingTagView: View {
    let tag: String

    var body: some View {
        Text(tag.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private var color: Color {
        switch tag {
        case "proxy": return .blue
        case "direct": return .green
        case "block": return .red
        default: return .gray
        }
    }
}
