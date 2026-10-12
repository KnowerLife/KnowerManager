import Foundation
import SwiftUI
import Vision
import AppKit
import Combine
import UniformTypeIdentifiers

class OCRManager: ObservableObject {
    static let shared = OCRManager()
    
    // Services
    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()
    @Published var aiService = AIService()
    
    // Access to settings for localization
    private let settings = SettingsManager.shared
    
    // State
    @Published var recognizedText: String = ""
    @Published var currentImage: NSImage?
    @Published var statusMessage: String = "" // Инициализируем в init
    @Published var isProcessing: Bool = false
    @Published var selectedLanguage: OCRLanguage = .russian
    @Published var recognitionHistory: [RecognitionResult] = []
    
    // AI State
    @Published var isAIProcessing: Bool = false
    
    private init() {
        // Устанавливаем начальное сообщение локализованно
        self.statusMessage = SettingsManager.shared.t(.ocrStatusReady)
    }
    
    // MARK: - Capture Actions
    
    func captureArea() { startCapture(type: .area) }
    func captureScreen() { startCapture(type: .screen) }
    func pasteFromClipboard() { startCapture(type: .clipboard) }
    
    private enum CaptureType { case area, screen, clipboard }
    
    private func startCapture(type: CaptureType) {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = settings.t(.ocrCapturing)
        
        Task {
            let image: NSImage?
            
            switch type {
            case .area:
                image = try? await screenCaptureService.captureSelectedArea()
            case .screen:
                image = try? await screenCaptureService.captureScreen()
            case .clipboard:
                image = screenCaptureService.getImageFromClipboard()
            }
            
            if let img = image {
                await recognizeText(from: img)
            } else {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = self.settings.t(.ocrCancel)
                }
            }
        }
    }
    
    // MARK: - OCR Logic
    
    private func recognizeText(from image: NSImage) async {
        await MainActor.run {
            self.currentImage = image
            self.statusMessage = self.settings.t(.ocrRecognizing)
        }
        
        do {
            let result = try await ocrService.recognizeText(
                from: image,
                language: selectedLanguage,
                confidence: 0.9
            )
            
            await MainActor.run {
                self.recognizedText = result.text
                
                // Добавляем в историю (ограничим до 20 последних)
                let newItem = RecognitionResult(text: result.text, confidence: result.confidence, preview: image)
                self.recognitionHistory.insert(newItem, at: 0)
                if self.recognitionHistory.count > 20 { self.recognitionHistory.removeLast() }
                
                // "Готово (95%)"
                let doneText = self.settings.t(.ocrDone)
                self.statusMessage = "\(doneText) (\(Int(result.confidence * 100))%)"
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                // "Ошибка: ..."
                let errorPrefix = self.settings.t(.errorPrefix)
                self.statusMessage = "\(errorPrefix)\(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - AI Logic
    
    func processWithAI(operation: AIOperation) {
        guard !recognizedText.isEmpty else { return }
        guard aiService.config.enabled else {
            statusMessage = settings.t(.ocrAIDisabled)
            return
        }
        
        isAIProcessing = true
        statusMessage = settings.t(.ocrAIProcessing)
        
        Task {
            do {
                let result = try await aiService.processText(recognizedText, operation: operation)
                await MainActor.run {
                    self.recognizedText = result
                    self.statusMessage = self.settings.t(.ocrAIDone)
                    self.isAIProcessing = false
                }
            } catch {
                await MainActor.run {
                    let errPrefix = self.settings.t(.ocrAIErrorPrefix)
                    self.statusMessage = "\(errPrefix)\(error.localizedDescription)"
                    self.isAIProcessing = false
                }
            }
        }
    }
    
    // MARK: - Export / Import
    
    func copyText() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        statusMessage = settings.t(.ocrCopied)
    }
    
    func clear() {
        recognizedText = ""
        currentImage = nil
        statusMessage = settings.t(.ocrCleared)
    }
    
    func selectFromHistory(_ item: RecognitionResult) {
        self.recognizedText = item.text
        self.currentImage = item.previewImage
        self.statusMessage = settings.t(.ocrHistoryLoaded)
    }
    
    // Сохранение в файл
    func saveToFile() {
        guard !recognizedText.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.title = settings.t(.ocrSaveTitle)
        savePanel.nameFieldStringValue = "scan_result.txt"
        savePanel.allowedContentTypes = [.text]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try self.recognizedText.write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.statusMessage = self.settings.t(.statusSaved)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.statusMessage = self.settings.t(.ocrSaveError)
                    }
                }
            }
        }
    }
    
    // Системный шеринг
    func shareContent() {
        guard !recognizedText.isEmpty else { return }
        let picker = NSSharingServicePicker(items: [recognizedText])
        // Находим активное окно для привязки пикера (хак для SwiftUI)
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            picker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .minY)
        }
    }
}
