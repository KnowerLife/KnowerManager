import Foundation
import Combine
import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

// MARK: - Enums

enum GenerationMethod: String, CaseIterable, Identifiable {
    // rawValue лучше оставить техническим (для логики), а для UI использовать localizedName
    case local = "local"
    case ssh = "ssh"
    
    var id: String { rawValue }
    
    // Вычисляемое свойство для отображения в Picker
    var localizedName: String {
        switch self {
        case .local: return SettingsManager.shared.t(.methodLocal) // "Локально" / "Local Device"
        case .ssh: return SettingsManager.shared.t(.methodSSH)     // "Через удаленный сервер" / "Via SSH Server"
        }
    }
}

// MARK: - Warp Manager

class WarpManager: ObservableObject {
    static let shared = WarpManager()
    
    // --- STATE ---
    @Published var isGenerating = false
    @Published var isScanningProxy = false
    @Published var statusMessage = ""
    @Published var generatedConfig = ""
    @Published var customEndpoint: String = "" // IP:Port from Scanner or Manual Input
    @Published var selectedFormat: ExportFormat = .amnezia
    
    // Инициализируем локализованным значением "Прокси: Авто"
    @Published var proxyStatus = SettingsManager.shared.t(.warpProxyAuto)
    
    // --- PARAMS ---
    @Published var generationMethod: GenerationMethod = .local
    @Published var amneziaParams = AmneziaParams()
    @Published var selectedRoutingRules: Set<RoutingRule> = []
    
    // --- SSH (Future use) ---
    @Published var sshHost = ""
    @Published var sshPort = "22"
    @Published var sshUser = "root"
    @Published var sshPassword = ""
    
    // --- INTERNAL ---
    private var detectedProxy: (host: String, port: Int)? = nil
    
    // MARK: - Proxy Detection
    func detectProxy() {
        guard !isScanningProxy else { return }
        isScanningProxy = true
        
        DispatchQueue.main.async {
            // "Сканирование..."
            self.proxyStatus = SettingsManager.shared.t(.proxyScan)
            self.statusMessage = ""
        }
        
        Task {
            if let proxy = await ProxyDetector.shared.detect(), let port = Int(proxy.port) {
                DispatchQueue.main.async {
                    self.detectedProxy = (proxy.host, port)
                    // "Прокси: 1.2.3.4:8080"
                    self.proxyStatus = "\(SettingsManager.shared.t(.proxyFound)) \(proxy.host):\(port)"
                    self.isScanningProxy = false
                }
            } else {
                DispatchQueue.main.async {
                    self.detectedProxy = nil
                    // "Напрямую (Без прокси)"
                    self.proxyStatus = SettingsManager.shared.t(.warpProxyDirect)
                    self.isScanningProxy = false
                }
            }
        }
    }
    
    // MARK: - Generation
    func generateConfig() {
        guard !isGenerating else { return }
        isGenerating = true
        // "Генерация..."
        statusMessage = SettingsManager.shared.t(.statusGenerating)
        generatedConfig = ""
        
        // Capture state on Main Thread to avoid data races in Task
        let currentMethod = generationMethod
        let currentProxy = detectedProxy
        let currentEndpointStr = customEndpoint
        let currentFormat = selectedFormat
        let currentParams = amneziaParams
        let currentRules = selectedRoutingRules
        
        Task {
            do {
                let rawData: RawWarpData
                
                // В будущем здесь можно добавить логику для SSH
                if currentMethod == .local {
                    rawData = try await WarpService.shared.createWarpIdentityRaw(proxy: currentProxy)
                } else {
                    // Placeholder for SSH logic
                    rawData = try await WarpService.shared.createWarpIdentityRaw(proxy: currentProxy)
                }
                
                // Определяем Endpoint (Custom или Default)
                let endpointToUse: (String, Int)?
                if !currentEndpointStr.isEmpty {
                    endpointToUse = parseEndpoint(currentEndpointStr)
                } else {
                    endpointToUse = nil // ConfigGenerator will use default
                }
                
                let configText = ConfigGenerator.shared.generate(
                    format: currentFormat,
                    data: rawData.response,
                    privateKey: rawData.privateKey,
                    amneziaParams: currentParams,
                    selectedRules: currentRules,
                    endpoint: endpointToUse
                )
                
                DispatchQueue.main.async {
                    self.generatedConfig = configText
                    // "Успешно!"
                    self.statusMessage = SettingsManager.shared.t(.statusSuccess)
                    self.isGenerating = false
                }
            } catch {
                DispatchQueue.main.async {
                    // "Ошибка: " + текст ошибки
                    self.statusMessage = "\(SettingsManager.shared.t(.errorPrefix))\(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
    
    // MARK: - QR Code Logic
    
    var qrCodeImage: NSImage? {
        guard !generatedConfig.isEmpty, !isConfigTooLargeForQR else { return nil }
        return generateQRCode(from: generatedConfig)
    }
    
    var isConfigTooLargeForQR: Bool {
        return generatedConfig.count > 2500
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.message = data
        filter.setValue("L", forKey: "inputCorrectionLevel")

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            let rep = NSCIImageRep(ciImage: scaledImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            return nsImage
        }
        return nil
    }
    
    // MARK: - Actions
    
    func saveToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "warp_config.\(selectedFormat.fileExtension)"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.generatedConfig.write(to: url, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    // "Сохранено в файл"
                    self.statusMessage = SettingsManager.shared.t(.statusSaved)
                }
            }
        }
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedConfig, forType: .string)
        // "Скопировано!"
        statusMessage = SettingsManager.shared.t(.statusCopied)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Очищаем статус только если он все еще "Скопировано!"
            if self.statusMessage == SettingsManager.shared.t(.statusCopied) {
                self.statusMessage = ""
            }
        }
    }
    
    // Helper to parse "IP:Port" string
    private func parseEndpoint(_ str: String) -> (String, Int) {
        let parts = str.split(separator: ":")
        if parts.count == 2, let port = Int(parts[1]) {
            return (String(parts[0]), port)
        }
        return ("engage.cloudflareclient.com", 2408)
    }
}
