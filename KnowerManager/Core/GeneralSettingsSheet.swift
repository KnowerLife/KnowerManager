import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GeneralSettingsSheet: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var hotkey = GlobalHotkeyManager.shared
    // ВАЖНО: наблюдаем логгер, иначе переключение «Показать логи» не обновляет UI.
    @ObservedObject var logger = AppLogger.shared
    @Environment(\.dismiss) private var dismiss
    
    // Проверка обновлений
    @State private var isCheckingUpdates = false
    @State private var updateMessage: String?
    @State private var updateDownloadURL: URL?
    @State private var updateFailed = false
    
    // Резервное копирование
    @State private var backupMessage: String?
    @State private var backupFailed = false
    
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
                    SettingsSection(title: settings.t(.settingsGeneral)) {
                        VStack(spacing: 12) {
                            // Launch at Login
                            SettingsRow(icon: "paperplane.fill", color: .purple, title: settings.t(.launchAtLogin), desc: settings.t(.launchAtLoginDesc), toggle: $settings.isLaunchAtLoginEnabled)
                            
                            Divider()
                            
                            // Hide Dock
                            SettingsRow(icon: "dock.rectangle", color: .blue, title: settings.t(.hideDockTitle), desc: settings.t(.hideDockDesc), toggle: $settings.hideDockIcon)
                            
                            Divider()
                            
                            // Open window on launch
                            SettingsRow(icon: "macwindow", color: .teal, title: settings.t(.openWindowOnLaunchTitle), desc: settings.t(.openWindowOnLaunchDesc), toggle: $settings.showWindowOnLaunch)
                            
                            Divider()
                            
                            // --- BUTTON: FORGET PASSWORD ---
                            SettingsActionRow(
                                icon: "key.slash.fill",
                                color: .red,
                                title: settings.t(.passForget),
                                desc: nil
                            ) {
                                IconActionButton(icon: "trash", color: .red, help: settings.t(.passForget)) {
                                    // Сбрасываем сохранённый пароль администратора
                                    PrivilegedRunner.shared.forgetPassword()
                                }
                            }
                        }
                    }
                    
                    // --- 2. AUTOMATION ---
                    SettingsSection(title: settings.t(.automationTitle)) {
                        VStack(spacing: 12) {
                            SettingsRow(icon: "bell.badge.fill", color: .red, title: settings.t(.notificationsTitle), desc: settings.t(.notificationsDesc), toggle: $settings.showNotifications)
                        }
                    }
                    
                    // --- 3. SCANNER (OCR) ---
                    SettingsSection(title: settings.t(.ocrSettingsTitle)) {
                        VStack(spacing: 12) {
                            SettingsRow(icon: "command", color: .indigo, title: settings.t(.ocrGlobalHotkeyTitle), desc: settings.t(.ocrGlobalHotkeyDesc), toggle: $settings.ocrGlobalHotkeyEnabled)
                            
                            Divider()
                            
                            hotkeyEditRow
                            
                            Divider()
                            
                            SettingsRow(icon: "doc.on.clipboard.fill", color: .teal, title: settings.t(.ocrAutoCopyTitle), desc: settings.t(.ocrAutoCopyDesc), toggle: $settings.ocrAutoCopyResult)
                        }
                    }
                    
                    // --- 4. LOGS ---
                    SettingsSection(title: settings.t(.logTitle)) {
                        VStack(spacing: 12) {
                            SettingsActionRow(
                                icon: "doc.text.magnifyingglass",
                                color: .gray,
                                title: settings.t(.logShow),
                                desc: settings.t(.logPath)
                            ) {
                                Button(logger.isUILogVisible ? settings.t(.logHide) : settings.t(.logShow)) {
                                    logger.isUILogVisible.toggle()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .fixedSize()
                            }
                            
                            if logger.isUILogVisible {
                                logViewer
                            }
                        }
                    }
                    
                    // --- 5. BACKUP ---
                    SettingsSection(title: settings.t(.backupTitle)) {
                        VStack(spacing: 12) {
                            SettingsActionRow(
                                icon: "externaldrive.fill",
                                color: .green,
                                title: settings.t(.backupCreateTitle),
                                desc: settings.t(.backupCreateDesc)
                            ) {
                                IconActionButton(icon: "square.and.arrow.up", color: .blue, help: settings.t(.backupCreateTitle)) {
                                    createBackup()
                                }
                            }
                            
                            Divider()
                            
                            SettingsActionRow(
                                icon: "arrow.counterclockwise.circle.fill",
                                color: .orange,
                                title: settings.t(.backupRestoreTitle),
                                desc: settings.t(.backupRestoreDesc)
                            ) {
                                IconActionButton(icon: "square.and.arrow.down", color: .orange, help: settings.t(.backupRestoreTitle)) {
                                    restoreBackup()
                                }
                            }
                            
                            if let message = backupMessage {
                                Label(message, systemImage: backupFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(backupFailed ? .red : .green)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // --- 6. APPEARANCE ---
                    SettingsSection(title: settings.t(.settingsAppearance)) {
                        VStack(spacing: 12) {
                            SettingsPickerRow(
                                icon: "globe",
                                color: .blue,
                                title: settings.t(.menuLanguage)
                            ) {
                                Picker("", selection: $settings.currentLanguage) {
                                    ForEach(AppLanguage.allCases) { lang in Text(lang.rawValue).tag(lang) }
                                }
                                .labelsHidden()
                                .frame(width: 120)
                            }
                            
                            Divider()
                            
                            SettingsPickerRow(
                                icon: "paintpalette.fill",
                                color: .orange,
                                title: settings.t(.menuTheme)
                            ) {
                                Picker("", selection: $settings.currentTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.localizedName(language: settings.currentLanguage)).tag(theme)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 120)
                            }
                        }
                    }
                    
                    // Footer: версия + проверка обновлений
                    VStack(spacing: 6) {
                        Text("Knower Manager \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: { checkForUpdates() }) {
                            HStack(spacing: 4) {
                                if isCheckingUpdates {
                                    ProgressView().controlSize(.mini).scaleEffect(0.7)
                                }
                                Text(isCheckingUpdates ? settings.t(.updateChecking) : settings.t(.btnCheckUpdates))
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCheckingUpdates)
                        
                        if let message = updateMessage {
                            HStack(spacing: 6) {
                                Text(message)
                                    .font(.caption2)
                                    .foregroundColor(updateFailed ? .red : .secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if let url = updateDownloadURL {
                                    Button(settings.t(.btnDownload)) {
                                        NSWorkspace.shared.open(url)
                                    }
                                    .font(.caption2)
                                    .fixedSize()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
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
        .frame(minWidth: DS.width, idealWidth: DS.width, maxWidth: DS.width,
               idealHeight: 700, maxHeight: 720)
    }
    
    // MARK: - Просмотр логов
    
    private var logViewer: some View {
        VStack(spacing: 8) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.uiLogLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(6)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            
            HStack(spacing: 12) {
                Button(settings.t(.logCopy)) {
                    let text = logger.uiLogLines.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .font(.caption)
                .fixedSize()
                
                Button(settings.t(.logClear)) {
                    logger.clear()
                }
                .font(.caption)
                .fixedSize()
                
                Spacer(minLength: 0)
                
                if let path = logger.currentLogPath {
                    IconActionButton(icon: "folder", color: .secondary, help: settings.t(.logPath)) {
                        NSWorkspace.shared.activateFileViewerSelecting([path])
                    }
                }
            }
        }
    }
    
    // MARK: - Резервное копирование

    private func createBackup() {
        let panel = NSSavePanel()
        panel.title = settings.t(.backupCreateTitle)
        panel.nameFieldStringValue = BackupManager.suggestedFileName()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.zip]
        backupMessage = nil
        backupFailed = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BackupManager.createBackup(to: url)
            backupFailed = false
            backupMessage = "\(settings.t(.backupSaved)): \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            backupFailed = true
            backupMessage = "\(settings.t(.backupFailed)): \(error.localizedDescription)"
        }
    }

    private func restoreBackup() {
        let panel = NSOpenPanel()
        panel.title = settings.t(.backupRestoreTitle)
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        backupMessage = nil
        backupFailed = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = settings.t(.backupConfirmTitle)
        alert.informativeText = settings.t(.backupConfirmBody)
        alert.alertStyle = .warning
        alert.addButton(withTitle: settings.t(.backupRestoreTitle))
        alert.addButton(withTitle: settings.t(.btnCancel))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try BackupManager.restoreBackup(from: url)
            backupFailed = false
            backupMessage = settings.t(.backupRestored)
        } catch {
            backupFailed = true
            backupMessage = "\(settings.t(.backupFailed)): \(error.localizedDescription)"
        }
    }

    // MARK: - Горячая клавиша

    private var hotkeyEditRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Строка с описанием и текущей комбинацией
            HStack(alignment: .center, spacing: 0) {
                IconSquare(icon: "keyboard", color: .indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.t(.ocrHotkeyChange))
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(hotkey.isRecording ? settings.t(.ocrHotkeyRecording) : settings.t(.ocrHotkeyChangeDesc))
                        .font(.caption)
                        .foregroundColor(hotkey.isRecording ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(hotkey.combinationString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(6)
                    .fixedSize()
                    .padding(.leading, 8)
            }
            
            // Отдельная строка под кнопки — так они не сжимают текст описания.
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button(hotkey.isRecording ? settings.t(.ocrHotkeyRecording) : settings.t(.ocrHotkeyRecord)) {
                    if hotkey.isRecording {
                        hotkey.stopRecording()
                    } else {
                        hotkey.startRecording()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .fixedSize()
                
                Button(settings.t(.ocrHotkeyReset)) {
                    hotkey.stopRecording()
                    hotkey.resetToDefault()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .fixedSize()
            }
        }
        .padding(.vertical, 2)
        .opacity(settings.ocrGlobalHotkeyEnabled ? 1 : 0.45)
        .disabled(!settings.ocrGlobalHotkeyEnabled)
        .onDisappear { hotkey.stopRecording() }
    }

    // MARK: - Проверка обновлений
    
    private func checkForUpdates() {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        updateMessage = nil
        updateDownloadURL = nil
        updateFailed = false
        
        Task {
            do {
                let result = try await UpdateChecker.checkForUpdates()
                await MainActor.run {
                    isCheckingUpdates = false
                    if result.isNewer {
                        updateMessage = String(format: settings.t(.updateAvailable), result.latestTag)
                        updateDownloadURL = result.url
                    } else {
                        updateMessage = settings.t(.updateUpToDate)
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingUpdates = false
                    updateFailed = true
                    updateMessage = settings.t(.updateCheckFailed)
                }
            }
        }
    }
}

// MARK: - COMPONENTS

/// Секция настроек: заголовок + содержимое в рамке.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            GroupBox {
                content()
                    .padding(4)
            }
        }
    }
}

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

/// Строка с переключателем. Текст занимает всё доступное место,
/// переключатель фиксирован — поэтому ничего не сжимается.
struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    @Binding var toggle: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 10)
            
            Toggle("", isOn: $toggle)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .fixedSize()
        }
        .padding(.vertical, 2)
    }
}

/// Строка с действием (кнопкой) справа. Описание переносится по строкам,
/// а действие фиксировано — поэтому ничего не сжимается.
struct SettingsActionRow<ActionContent: View>: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String?
    @ViewBuilder var action: () -> ActionContent
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            IconSquare(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 10)
            
            action()
                .fixedSize()
        }
        .padding(.vertical, 2)
    }
}

/// Строка с пикером справа. Подпись слева не сжимается.
struct SettingsPickerRow<PickerContent: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder var picker: () -> PickerContent
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            IconSquare(icon: icon, color: color)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
            picker()
                .fixedSize()
        }
        .padding(.vertical, 2)
    }
}

/// Круглая иконка-кнопка (действия в строках настроек).
struct IconActionButton: View {
    let icon: String
    var color: Color = .secondary
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .fixedSize()
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
        .fixedSize()
    }
}
