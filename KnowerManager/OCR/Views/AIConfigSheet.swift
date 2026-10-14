import SwiftUI

// MARK: - Настройки AI (провайдер, ключ, модель, параметры)
//
// Вынесено из ContentView в отдельный файл и переписано из однострочника.
// Изменения применяются к сервису только по кнопке «Сохранить»; «Отмена»
// возвращает исходную конфигурацию (включая результат пробного подключения).

struct AIConfigSheet: View {
    @ObservedObject var ocrManager: OCRManager
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var settings = SettingsManager.shared

    /// Редактируемая копия конфигурации.
    @State private var draft: AIConfig
    /// Исходная конфигурация — для отката при отмене.
    private let original: AIConfig

    @State private var showKey = false
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testOK = false

    init(ocrManager: OCRManager) {
        self.ocrManager = ocrManager
        let current = ocrManager.aiService.config
        self.original = current
        _draft = State(initialValue: current)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    generalSection
                    providerSection
                    advancedSection
                    testSection
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 460, height: 560)
    }

    // MARK: - Header / Footer

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
            Text(settings.t(.ocrAISettings))
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    private var footer: some View {
        HStack {
            Button(settings.t(.btnCancel)) {
                // Откатываем возможные изменения от «Проверить подключение».
                ocrManager.aiService.config = original
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)

            Spacer()

            Button(settings.t(.btnSave)) {
                ocrManager.aiService.config = draft
                ocrManager.aiService.saveConfig()
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(ModernButtonStyle(color: .blue))
        }
        .padding()
    }

    // MARK: - Sections

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: settings.t(.aiProvider))

            Toggle(settings.t(.aiEnable), isOn: $draft.enabled)
                .toggleStyle(SwitchToggleStyle())

            Picker(settings.t(.aiProvider), selection: $draft.provider) {
                ForEach(AIServiceProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: settings.t(.aiModel))

            // Модель: текстовое поле + список подсказок для провайдера.
            HStack(spacing: 6) {
                TextField(settings.t(.aiModel), text: $draft.model)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Menu {
                    ForEach(draft.provider.availableModels, id: \.self) { model in
                        Button(model) { draft.model = model }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if draft.provider != .local {
                HStack(spacing: 6) {
                    if showKey {
                        TextField(settings.t(.aiApiKey), text: $draft.apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField(settings.t(.aiApiKey), text: $draft.apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button(showKey ? settings.t(.aiHideKey) : settings.t(.aiShowKey)) {
                        showKey.toggle()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: settings.t(.aiAdvanced))

            HStack {
                Text(settings.t(.aiTemperature))
                    .font(.system(size: 12))
                Slider(value: $draft.temperature, in: 0...2, step: 0.1)
                Text(String(format: "%.1f", draft.temperature))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            HStack {
                Text(settings.t(.aiMaxTokens))
                    .font(.system(size: 12))
                Spacer()
                TextField("", value: $draft.maxTokens, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 90)
            }
        }
    }

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        }
                        Text(settings.t(.aiTestConnection))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTesting || (!draft.enabled && draft.provider != .local))

                Spacer()
            }

            if let message = testMessage {
                Label(message, systemImage: testOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(testOK ? .green : .red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private func testConnection() {
        // Применяем черновик, чтобы проверялись именно текущие значения.
        ocrManager.aiService.config = draft
        isTesting = true
        testMessage = nil

        Task {
            do {
                let ok = try await ocrManager.aiService.testConnection()
                isTesting = false
                testOK = ok
                testMessage = ok ? settings.t(.aiTestSuccess) : settings.t(.aiMsgUnknown)
            } catch {
                isTesting = false
                testOK = false
                testMessage = error.localizedDescription
            }
        }
    }
}
