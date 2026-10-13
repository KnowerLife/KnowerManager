import Foundation
import SwiftUI
import Vision
import AppKit
import Combine
import UniformTypeIdentifiers
import NaturalLanguage

class OCRManager: ObservableObject {
    static let shared = OCRManager()

    // MARK: - Services
    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let preprocessor = ImagePreprocessor()
    private let importService = DocumentImportService()
    @Published var aiService = AIService()
    @Published var speech = SpeechService.shared

    private let settings = SettingsManager.shared

    // MARK: - Настройки распознавания (сохраняются между запусками)
    @Published var ocrOptions: OCROptions {
        didSet { persist(ocrOptions, key: Self.optionsKey) }
    }
    @Published var preprocessingOptions: ImagePreprocessingOptions {
        didSet { persist(preprocessingOptions, key: Self.preprocessingKey) }
    }

    // MARK: - Состояние
    @Published var recognizedText: String = "" {
        didSet {
            guard !isSyncingText, pages.indices.contains(activePageIndex) else { return }
            pages[activePageIndex].text = recognizedText
        }
    }
    @Published var currentImage: NSImage?
    @Published var textBlocks: [OCRTextBlock] = []
    @Published var barcodes: [BarcodeResult] = []
    @Published var detectedLanguage: DetectedLanguage?
    /// Язык текста, заданный вручную (nil — автоопределение).
    @Published var textLanguageOverride: String?
    @Published var pages: [OCRPage] = []
    @Published var activePageIndex: Int = 0
    @Published var showTextBoxes: Bool = true
    @Published var statusMessage: String
    @Published var isProcessing: Bool = false
    @Published var isAIProcessing: Bool = false
    @Published var recognitionHistory: [RecognitionResult] = [] {
        didSet { scheduleHistorySave() }
    }

    private var isSyncingText = false

    private static let optionsKey = "ocrOptions"
    private static let preprocessingKey = "ocrPreprocessing"

    private init() {
        self.ocrOptions = Self.load(OCROptions.self, key: Self.optionsKey) ?? .default
        self.preprocessingOptions = Self.load(ImagePreprocessingOptions.self, key: Self.preprocessingKey) ?? .default
        self.statusMessage = SettingsManager.shared.t(.ocrStatusReady)
        self.recognitionHistory = Self.loadHistory()
    }

    // MARK: - Персистентность

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - История распознаваний (на диске)

    /// Путь к файлу истории в Application Support/KnowerManager.
    nonisolated static func historyStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("KnowerManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ocr_history.json")
    }

    private nonisolated static func loadHistory() -> [RecognitionResult] {
        guard let data = try? Data(contentsOf: historyStorageURL()) else { return [] }
        return (try? JSONDecoder().decode([RecognitionResult].self, from: data)) ?? []
    }

    /// Сохраняет историю в фоне (снимок делается на главном потоке).
    private func scheduleHistorySave() {
        let snapshot = recognitionHistory
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: Self.historyStorageURL(), options: .atomic)
        }
    }

    /// Полностью очищает историю распознаваний.
    func clearHistory() {
        recognitionHistory.removeAll()
        statusMessage = settings.t(.ocrCleared)
    }

    // MARK: - Захват экрана

    func captureArea() { startCapture(type: .area) }
    func captureScreen() { startCapture(type: .screen) }
    func pasteFromClipboard() { startCapture(type: .clipboard) }

    private enum CaptureType { case area, screen, clipboard }

    private func startCapture(type: CaptureType) {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = settings.t(.ocrCapturing)

        Task {
            var image: NSImage?
            var captureError: Error?

            switch type {
            case .area:
                do { image = try await screenCaptureService.captureSelectedArea() } catch { captureError = error }
            case .screen:
                do { image = try await screenCaptureService.captureScreen() } catch { captureError = error }
            case .clipboard:
                image = screenCaptureService.getImageFromClipboard()
            }

            if let img = image {
                let page = await self.buildPage(from: img, title: self.settings.t(.ocrArea))
                await MainActor.run {
                    self.pages = [page]
                    self.activePageIndex = 0
                    self.syncActivePage()
                    self.appendToHistory(page)
                    self.isProcessing = false
                    self.finishStatus(for: page)
                    self.autoCopyIfEnabled(for: page)
                }
            } else {
                await MainActor.run {
                    self.isProcessing = false
                    if let error = captureError {
                        self.statusMessage = "\(self.settings.t(.errorPrefix))\(error.localizedDescription)"
                    } else {
                        self.statusMessage = self.settings.t(.ocrCancel)
                    }
                }
            }
        }
    }

    // MARK: - Импорт файлов / PDF

    func importURLs(_ urls: [URL]) {
        guard !isProcessing, !urls.isEmpty else { return }
        isProcessing = true
        statusMessage = settings.t(.ocrImporting)

        Task {
            let imported = importService.loadPages(from: urls,
                                                   preferEmbeddedPDFText: ocrOptions.preferEmbeddedPDFText)
            guard !imported.isEmpty else {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusMessage = self.settings.t(.ocrImportEmpty)
                }
                return
            }

            var newPages: [OCRPage] = []
            for item in imported {
                let page = await self.buildPage(from: item.image, title: item.title, embeddedText: item.embeddedText)
                newPages.append(page)
            }

            await MainActor.run {
                self.pages = newPages
                self.activePageIndex = 0
                self.syncActivePage()
                newPages.forEach { self.appendToHistory($0) }
                self.isProcessing = false
                let countText = self.settings.t(.ocrImportDone)
                self.statusMessage = "\(countText) \(newPages.count)"
            }
        }
    }

    func importFromScanner(_ image: NSImage) {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = settings.t(.ocrRecognizing)
        Task {
            let page = await self.buildPage(from: image, title: self.settings.t(.ocrImportScanner))
            await MainActor.run {
                self.pages.append(page)
                self.activePageIndex = self.pages.count - 1
                self.syncActivePage()
                self.appendToHistory(page)
                self.isProcessing = false
                self.finishStatus(for: page)
            }
        }
    }

    // MARK: - Пайплайн распознавания

    private func buildPage(from image: NSImage, title: String, embeddedText: String? = nil) async -> OCRPage {
        let processed = preprocessor.process(image, options: preprocessingOptions)

        var text = ""
        var confidence = 0.0
        var blocks: [OCRTextBlock] = []

        if let embedded = embeddedText {
            text = embedded
            confidence = 1.0
        } else {
            do {
                let output = try await ocrService.recognizeText(in: processed, options: ocrOptions)
                text = output.text
                confidence = output.averageConfidence
                blocks = ocrOptions.keepTextBlocks ? output.blocks : []
            } catch {
                text = ""
            }
        }

        var foundBarcodes: [BarcodeResult] = []
        if ocrOptions.detectBarcodes {
            foundBarcodes = (try? await ocrService.detectBarcodes(in: processed)) ?? []
        }

        return OCRPage(image: processed,
                       originalImage: image,
                       text: text,
                       confidence: confidence,
                       blocks: blocks,
                       barcodes: foundBarcodes,
                       title: title,
                       embeddedText: embeddedText)
    }

    /// Повторно распознаёт активную страницу с текущими настройками.
    func reRecognizeActivePage() {
        guard !isProcessing, pages.indices.contains(activePageIndex) else { return }
        let page = pages[activePageIndex]
        isProcessing = true
        statusMessage = settings.t(.ocrRecognizing)

        Task {
            let rebuilt = await buildPage(from: page.originalImage ?? page.image,
                                          title: page.title,
                                          embeddedText: nil)
            await MainActor.run {
                self.pages[self.activePageIndex] = rebuilt
                self.syncActivePage()
                self.isProcessing = false
                self.finishStatus(for: rebuilt)
            }
        }
    }

    // MARK: - Страницы

    func setActivePage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        activePageIndex = index
        syncActivePage()
    }

    func nextPage() { setActivePage(activePageIndex + 1) }
    func previousPage() { setActivePage(activePageIndex - 1) }

    func removeActivePage() {
        guard pages.indices.contains(activePageIndex) else { return }
        pages.remove(at: activePageIndex)
        if pages.isEmpty {
            activePageIndex = 0
            clearSessionState()
            statusMessage = settings.t(.ocrCleared)
        } else {
            activePageIndex = min(activePageIndex, pages.count - 1)
            syncActivePage()
        }
    }

    private func syncActivePage() {
        guard pages.indices.contains(activePageIndex) else {
            clearSessionState()
            return
        }
        let page = pages[activePageIndex]
        isSyncingText = true
        recognizedText = page.text
        isSyncingText = false
        currentImage = page.image
        textBlocks = page.blocks
        barcodes = page.barcodes
        textLanguageOverride = nil
        if page.embeddedText != nil {
            detectedLanguage = DetectedLanguage(code: recognizeLanguageCode(ocrOptions.languages.first), confidence: 1.0)
        } else {
            detectedLanguage = detectLanguage(of: page.text)
        }
    }

    private func clearSessionState() {
        isSyncingText = true
        recognizedText = ""
        isSyncingText = false
        currentImage = nil
        textBlocks = []
        barcodes = []
        detectedLanguage = nil
        textLanguageOverride = nil
    }

    private func appendToHistory(_ page: OCRPage) {
        guard !page.isEmptyText else { return }
        let item = RecognitionResult(text: page.text,
                                     confidence: page.confidence,
                                     preview: page.image,
                                     detectedLanguage: detectedLanguage?.code,
                                     blocks: page.blocks,
                                     barcodes: page.barcodes)
        recognitionHistory.insert(item, at: 0)
        if recognitionHistory.count > 20 { recognitionHistory.removeLast() }
    }

    private func finishStatus(for page: OCRPage) {
        let done = settings.t(.ocrDone)
        statusMessage = "\(done) (\(Int(page.confidence * 100))%)"
    }
    
    /// Если в настройках включено авто-копирование — кладёт текст страницы в буфер обмена.
    private func autoCopyIfEnabled(for page: OCRPage) {
        guard SettingsManager.shared.ocrAutoCopyResult else { return }
        let text = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(page.text, forType: .string)
        let done = settings.t(.ocrDone)
        statusMessage = "\(done) (\(Int(page.confidence * 100))%) · \(settings.t(.ocrCopied))"
    }

    // MARK: - Определение языка

    private func detectLanguage(of text: String) -> DetectedLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        return DetectedLanguage(code: language.rawValue, confidence: hypotheses[language] ?? 0)
    }

    private func recognizeLanguageCode(_ code: String?) -> String {
        guard let code = code else { return Locale.current.language.languageCode?.identifier ?? "en" }
        return code
    }

    /// Язык текста задан вручную (а не автоопределён).
    var isTextLanguageManual: Bool { textLanguageOverride != nil }

    /// Вручную задаёт язык распознанного текста (влияет на бейдж и озвучку).
    /// `nil` — вернуть автоопределение.
    func setTextLanguage(_ code: String?) {
        textLanguageOverride = code
        if let code {
            detectedLanguage = DetectedLanguage(code: code, confidence: 1.0)
        } else {
            detectedLanguage = detectLanguage(of: recognizedText)
        }
    }

    /// Перераспознаёт активную страницу в выбранном языке.
    func reRecognizeActivePage(in language: OCRLanguage) {
        guard !isProcessing, pages.indices.contains(activePageIndex) else { return }
        ocrOptions.languages = [language.rawValue]
        textLanguageOverride = nil
        reRecognizeActivePage()
    }

    // MARK: - AI

    func processWithAI(operation: AIOperation) {
        guard !recognizedText.isEmpty else { return }
        guard aiService.config.enabled else {
            statusMessage = settings.t(.ocrAIDisabled)
            return
        }
        if aiService.config.provider != .local && aiService.config.apiKey.isEmpty {
            statusMessage = settings.t(.aiErrConfig)
            return
        }

        isAIProcessing = true
        statusMessage = settings.t(.ocrAIProcessing)

        Task {
            do {
                let sourceText = recognizedText
                let result = try await aiService.processText(sourceText, operation: operation)
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

    // MARK: - Копирование / очистка

    func copyText() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        statusMessage = settings.t(.ocrCopied)
    }

    /// Копирует текст всех страниц.
    func copyAllText() {
        let all = fullText()
        guard !all.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(all, forType: .string)
        statusMessage = settings.t(.ocrCopied)
    }

    func copyBarcode(_ barcode: BarcodeResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(barcode.value, forType: .string)
        statusMessage = settings.t(.ocrCopied)
    }

    func clear() {
        pages = []
        activePageIndex = 0
        clearSessionState()
        statusMessage = settings.t(.ocrCleared)
    }

    func selectFromHistory(_ item: RecognitionResult) {
        let page = OCRPage(image: item.previewImage ?? NSImage(),
                           text: item.text,
                           confidence: item.confidence,
                           blocks: item.blocks ?? [],
                           barcodes: item.barcodes ?? [],
                           title: settings.t(.ocrHistory))
        pages = [page]
        activePageIndex = 0
        syncActivePage()
        statusMessage = settings.t(.ocrHistoryLoaded)
    }

    // MARK: - Озвучка

    func speakActivePage() {
        let code = detectedLanguage?.code ?? recognizeLanguageCode(ocrOptions.languages.first)
        speech.speak(recognizedText, languageCode: code)
    }

    func stopSpeaking() { speech.stop() }

    // MARK: - Экспорт

    func fullText() -> String {
        var chunks: [String] = []
        for (index, page) in pages.enumerated() {
            let body = page.text
            if pages.count > 1 {
                chunks.append("--- \(settings.t(.ocrPage)) \(index + 1) ---\n\(body)")
            } else {
                chunks.append(body)
            }
        }
        return chunks.joined(separator: "\n\n")
    }

    func export(as format: OCRExportFormat) {
        guard !pages.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = settings.t(.ocrExport)
        panel.nameFieldStringValue = defaultExportName(ext: format.fileExtension)
        switch format {
        case .txt: panel.allowedContentTypes = [.plainText]
        case .markdown: panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        case .json: panel.allowedContentTypes = [.json]
        case .searchablePDF: panel.allowedContentTypes = [.pdf]
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self.writeExport(format: format, to: url)
                DispatchQueue.main.async { self.statusMessage = self.settings.t(.ocrExportDone) }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "\(self.settings.t(.ocrExportError)) \(error.localizedDescription)"
                }
            }
        }
    }

    private func defaultExportName(ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "scan_\(formatter.string(from: Date())).\(ext)"
    }

    private func writeExport(format: OCRExportFormat, to url: URL) throws {
        switch format {
        case .txt:
            try fullText().write(to: url, atomically: true, encoding: .utf8)
        case .markdown:
            try buildMarkdown().write(to: url, atomically: true, encoding: .utf8)
        case .json:
            let data = try JSONEncoder().encode(pages.map { ExportPage(page: $0) })
            try data.write(to: url)
        case .searchablePDF:
            try SearchablePDFExporter.export(pages: SearchablePDFExporter.pages(from: pages), to: url)
        }
    }

    private func buildMarkdown() -> String {
        var lines: [String] = []
        for (index, page) in pages.enumerated() {
            lines.append("# \(settings.t(.ocrPage)) \(index + 1)")
            if !page.barcodes.isEmpty {
                lines.append("")
                for barcode in page.barcodes {
                    lines.append("- `\(barcode.symbology)`: \(barcode.value)")
                }
            }
            lines.append("")
            lines.append(page.text)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func saveToFile() { export(as: .txt) }

    // MARK: - Системный шеринг

    func shareContent() {
        guard !recognizedText.isEmpty else { return }
        let picker = NSSharingServicePicker(items: [recognizedText])
        let anchor = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible })
        if let window = anchor, let view = window.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else if let view = NSApp.windows.first?.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}

/// Сериализуемая страница для JSON-экспорта.
private struct ExportPage: Codable {
    let title: String
    let text: String
    let confidence: Double
    let detectedLanguage: String?
    let barcodes: [BarcodeResult]
    let blocks: [OCRTextBlock]

    init(page: OCRPage) {
        self.title = page.title
        self.text = page.text
        self.confidence = page.confidence
        self.detectedLanguage = nil
        self.barcodes = page.barcodes
        self.blocks = page.blocks
    }
}
