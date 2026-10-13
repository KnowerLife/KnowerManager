import SwiftUI

struct GeneralSettingsSheet: View {
    @ObservedObject var settings = SettingsManager.shared
    @StateObject var knowerWatch = KnowerWatchService.shared
    @Environment(\.dismiss) private var dismiss
    
    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(settings.t(.settingsTitle)).font(.headline)
                Spacer()
                Button(settings.t(.btnDone)) {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    
                    // --- 1. GENERAL SETTINGS + SECURITY ---
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: settings.t(.settingsGeneral))
                        GroupBox {
                            VStack(spacing: 12) {
                                // Launch at Login
                                SettingsRow(icon: "paperplane.fill", color: .purple, title: settings.t(.launchAtLogin), desc: settings.t(.launchAtLoginDesc), toggle: $settings.isLaunchAtLoginEnabled)
                                
                                Divider()
                                
                                // Hide Dock
                                SettingsRow(icon: "dock.rectangle", color: .blue, title: settings.t(.hideDockTitle), desc: settings.t(.hideDockDesc), toggle: $settings.hideDockIcon)
                                
                                Divider()
                                
                                // --- BUTTON: FORGET PASSWORD (НОВОЕ) ---
                                HStack(alignment: .center) {
                                    IconSquare(icon: "key.slash.fill", color: .red) // Красный ключ
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(settings.t(.passForget)) // "Забыть сохраненный пароль"
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    Spacer()
                                    Button(action: {
                                        // Вызываем метод сброса из KnowerManager
                                        KnowerManager.shared.forgetPassword()
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .padding(6)
                                            .background(Color.black.opacity(0.05))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(settings.t(.passForget))
                                }
                                .padding(.vertical, 2)
                            }
                            .padding(4)
                        }
                    }
                    
                    // --- 2. AUTOMATION ---
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: settings.t(.automationTitle))
                        GroupBox {
                            VStack(spacing: 12) {
                                SettingsRow(icon: "bell.badge.fill", color: .red, title: settings.t(.notificationsTitle), desc: settings.t(.notificationsDesc), toggle: $settings.showNotifications)
                                Divider()
                                SettingsRow(icon: "eye.fill", color: .green, title: settings.t(.kwTitle), desc: settings.t(.kwDesc), toggle: $knowerWatch.isEnabled)
                            }
                            .padding(4)
                        }
                    }
                    
                    // --- 3. APPEARANCE ---
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: settings.t(.settingsAppearance))
                        GroupBox {
                            VStack(spacing: 12) {
                                HStack {
                                    IconSquare(icon: "globe", color: .blue)
                                    Text(settings.t(.menuLanguage))
                                    Spacer()
                                    Picker("", selection: $settings.currentLanguage) {
                                        ForEach(AppLanguage.allCases) { lang in Text(lang.rawValue).tag(lang) }
                                    }
                                    .labelsHidden().frame(width: 120)
                                }
                                Divider()
                                HStack {
                                    IconSquare(icon: "paintpalette.fill", color: .orange)
                                    Text(settings.t(.menuTheme))
                                    Spacer()
                                    Picker("", selection: $settings.currentTheme) {
                                        ForEach(AppTheme.allCases) { theme in
                                            Text(theme.localizedName(language: settings.currentLanguage)).tag(theme)
                                        }
                                    }
                                    .labelsHidden().frame(width: 120)
                                }
                            }
                            .padding(4)
                        }
                    }
                    
                    // Footer
                    VStack(spacing: 4) {
                        Text("Knower Manager \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("© 2025 KnowerLife")
                            .font(.caption2)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: 420, idealHeight: 700, maxHeight: 720)
    }
}

// MARK: - COMPONENTS

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
            .textCase(.uppercase)
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    @Binding var toggle: Bool
    
    var body: some View {
        HStack(alignment: .center) {
            IconSquare(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            Toggle("", isOn: $toggle)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

struct IconSquare: View {
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.2))
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
        }
        .padding(.trailing, 8)
    }
}
