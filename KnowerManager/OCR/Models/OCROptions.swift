import Foundation
import AppKit
import ImageIO

// MARK: - Тонкие настройки распознавания

/// Уровень распознавания Vision: точный или быстрый.
enum OCRRecognitionLevel: String, CaseIterable, Identifiable, Codable {
    case accurate
    case fast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accurate: return SettingsManager.shared.t(.ocrLevelAccurate)
        case .fast: return SettingsManager.shared.t(.ocrLevelFast)
        }
    }

    var icon: String {
        switch self {
        case .accurate: return "scope"
        case .fast: return "bolt"
        }
    }
}

/// Ориентация изображения перед передачей в Vision.
/// Позволяет распознавать перевёрнутые / повёрнутые сканы без ручного разворота.
enum OCRImageOrientation: String, CaseIterable, Identifiable, Codable {
    case up
    case down
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .up: return SettingsManager.shared.t(.ocrOrientationUp)
        case .down: return SettingsManager.shared.t(.ocrOrientationDown)
        case .left: return SettingsManager.shared.t(.ocrOrientationLeft)
        case .right: return SettingsManager.shared.t(.ocrOrientationRight)
        }
    }

    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}

/// Полный набор параметров распознавания, сериализуется между запусками.
struct OCROptions: Codable, Equatable {
    /// Точный/быстрый движок.
    var recognitionLevel: OCRRecognitionLevel = .accurate
    /// Языки распознавания (коды OCRLanguage.rawValue), порядок = приоритет.
    var languages: [String] = [OCRLanguage.russian.rawValue, OCRLanguage.english.rawValue]
    /// Автокоррекция слов по словарю языка.
    var usesLanguageCorrection: Bool = true
    /// Vision сам определяет язык/скрипт (ревизия 3+). Полезно, когда язык неизвестен.
    var automaticallyDetectsLanguage: Bool = true
    /// Минимальная высота текста (0 — по умолчанию, авто).
    var minimumTextHeight: Double = 0.0
    /// Пользовательский словарь (термины, бренды, названия).
    var customWords: [String] = []
    /// Ориентация входного изображения.
    var imageOrientation: OCRImageOrientation = .up
    /// Распознавать QR/штрих-коды вместе с текстом.
    var detectBarcodes: Bool = true
    /// Оставлять рамки распознанных блоков (bounding box).
    var keepTextBlocks: Bool = true
    /// Если в PDF уже есть текстовый слой — использовать его вместо OCR.
    var preferEmbeddedPDFText: Bool = true

    static let `default` = OCROptions()
}

// MARK: - Предобработка изображения

/// Параметры улучшения изображения перед OCR (Core Image).
struct ImagePreprocessingOptions: Codable, Equatable {
    var isEnabled: Bool = false
    var grayscale: Bool = true
    /// 0.5...2.0 (1.0 — без изменений)
    var contrast: Double = 1.15
    /// -0.5...0.5 (0.0 — без изменений)
    var brightness: Double = 0.0
    /// 0.0...2.0
    var sharpness: Double = 0.4
    var invert: Bool = false
    /// Бинаризация (чёрное/белое) с локальным порогом.
    var binarize: Bool = false
    /// 0.0...1.0
    var binarizeThreshold: Double = 0.5
    /// 1.0...3.0 — увеличение помогает распознавать мелкий текст.
    var upscale: Double = 1.0

    static let `default` = ImagePreprocessingOptions()

    var isIdentity: Bool {
        !isEnabled || (!grayscale && contrast == 1.0 && brightness == 0 && sharpness == 0
                       && !invert && !binarize && upscale == 1.0)
    }
}

// MARK: - Результаты распознавания

/// Распознанный текстовый блок с рамкой (нормализованные координаты, origin — снизу слева).
struct OCRTextBlock: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let confidence: Double
    let rect: CGRect

    init(id: UUID = UUID(), text: String, confidence: Double, rect: CGRect) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.rect = rect
    }
}

/// Распознанный штрих-код / QR-код.
struct BarcodeResult: Identifiable, Codable, Equatable {
    let id: UUID
    let value: String
    let symbology: String
    let rect: CGRect

    init(id: UUID = UUID(), value: String, symbology: String, rect: CGRect) {
        self.id = id
        self.value = value
        self.symbology = symbology
        self.rect = rect
    }

    var isURL: Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme != nil
    }
}

/// Результат определения языка текста.
struct DetectedLanguage {
    let code: String
    let confidence: Double

    var displayName: String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
}

// MARK: - Многостраничный документ

/// Одна страница в текущем сеансе сканирования.
struct OCRPage: Identifiable {
    let id: UUID
    var image: NSImage
    /// Исходное (необработанное) изображение — используется для повторного OCR.
    var originalImage: NSImage?
    var text: String
    var confidence: Double
    var blocks: [OCRTextBlock]
    var barcodes: [BarcodeResult]
    var title: String
    /// Текст, уже встроенный в PDF (если импорт был из PDF с текстовым слоем).
    var embeddedText: String?

    init(id: UUID = UUID(),
         image: NSImage,
         originalImage: NSImage? = nil,
         text: String = "",
         confidence: Double = 0,
         blocks: [OCRTextBlock] = [],
         barcodes: [BarcodeResult] = [],
         title: String = "",
         embeddedText: String? = nil) {
        self.id = id
        self.image = image
        self.originalImage = originalImage ?? image
        self.text = text
        self.confidence = confidence
        self.blocks = blocks
        self.barcodes = barcodes
        self.title = title
        self.embeddedText = embeddedText
    }

    var isEmptyText: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Форматы экспорта

enum OCRExportFormat: String, CaseIterable, Identifiable {
    case txt
    case markdown
    case json
    case searchablePDF

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return SettingsManager.shared.t(.ocrExportTxt)
        case .markdown: return SettingsManager.shared.t(.ocrExportMarkdown)
        case .json: return SettingsManager.shared.t(.ocrExportJSON)
        case .searchablePDF: return SettingsManager.shared.t(.ocrExportSearchablePDF)
        }
    }

    var icon: String {
        switch self {
        case .txt: return "doc.text"
        case .markdown: return "text.badge.checkmark"
        case .json: return "curlybraces"
        case .searchablePDF: return "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .markdown: return "md"
        case .json: return "json"
        case .searchablePDF: return "pdf"
        }
    }
}

// MARK: - Озвучка (TTS)

struct OCRTTSConfig: Codable, Equatable {
    var voiceIdentifier: String?
    /// Язык озвучки (базовый код, например "ru"). nil — брать язык из текста.
    var languageCode: String?
    /// Значение AVSpeechUtteranceDefaultSpeechRate = 0.5
    var rate: Float = 0.5
    var pitch: Float = 1.0
    var volume: Float = 1.0

    static let `default` = OCRTTSConfig()
}
