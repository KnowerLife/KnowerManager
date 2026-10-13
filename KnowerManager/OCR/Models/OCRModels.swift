import Foundation
import AppKit

// MARK: - OCR Models

enum OCRLanguage: String, CaseIterable, Identifiable, Codable {
    case russian = "ru"
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt"
    case ukrainian = "uk"
    case polish = "pl"
    case turkish = "tr"
    case dutch = "nl"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "no"
    case finnish = "fi"
    case czech = "cs"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case hebrew = "he"
    case thai = "th"
    case vietnamese = "vi"
    
    var id: String { rawValue }
    
    /// Код, который ожидает Vision (BCP-47). Для большинства языков — регион по умолчанию.
    var visionCode: String {
        switch self {
        case .russian: return "ru-RU"
        case .english: return "en-US"
        case .german: return "de-DE"
        case .french: return "fr-FR"
        case .spanish: return "es-ES"
        case .italian: return "it-IT"
        case .portuguese: return "pt-BR"
        case .ukrainian: return "uk-UA"
        case .polish: return "pl-PL"
        case .turkish: return "tr-TR"
        case .dutch: return "nl-NL"
        case .swedish: return "sv-SE"
        case .danish: return "da-DK"
        case .norwegian: return "nb-NO"
        case .finnish: return "fi-FI"
        case .czech: return "cs-CZ"
        case .chineseSimplified: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        case .arabic: return "ar-SA"
        case .hebrew: return "he-IL"
        case .thai: return "th-TH"
        case .vietnamese: return "vi-VT"
        }
    }
    
    /// Базовый код языка — для AVSpeechSynthesizer и NLLanguageRecognizer.
    var baseCode: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return SettingsManager.shared.t(.langRu)
        case .english: return SettingsManager.shared.t(.langEn)
        case .german: return SettingsManager.shared.t(.langDe)
        case .french: return SettingsManager.shared.t(.langFr)
        case .spanish: return SettingsManager.shared.t(.langEs)
        case .italian: return SettingsManager.shared.t(.langIt)
        case .portuguese: return SettingsManager.shared.t(.langPt)
        case .ukrainian: return SettingsManager.shared.t(.langUk)
        case .polish: return SettingsManager.shared.t(.langPl)
        case .turkish: return SettingsManager.shared.t(.langTr)
        case .dutch: return SettingsManager.shared.t(.langNl)
        case .swedish: return SettingsManager.shared.t(.langSv)
        case .danish: return SettingsManager.shared.t(.langDa)
        case .norwegian: return SettingsManager.shared.t(.langNo)
        case .finnish: return SettingsManager.shared.t(.langFi)
        case .czech: return SettingsManager.shared.t(.langCs)
        case .chineseSimplified: return SettingsManager.shared.t(.langZhHans)
        case .chineseTraditional: return SettingsManager.shared.t(.langZhHant)
        case .japanese: return SettingsManager.shared.t(.langJa)
        case .korean: return SettingsManager.shared.t(.langKo)
        case .arabic: return SettingsManager.shared.t(.langAr)
        case .hebrew: return SettingsManager.shared.t(.langHe)
        case .thai: return SettingsManager.shared.t(.langTh)
        case .vietnamese: return SettingsManager.shared.t(.langVi)
        }
    }
    
    /// Флаг страны для компактного списка выбора языков.
    var flag: String {
        switch self {
        case .russian: return "🇷🇺"
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .ukrainian: return "🇺🇦"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        case .danish: return "🇩🇰"
        case .norwegian: return "🇳🇴"
        case .finnish: return "🇫🇮"
        case .czech: return "🇨🇿"
        case .chineseSimplified: return "🇨🇳"
        case .chineseTraditional: return "🇹🇼"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .hebrew: return "🇮🇱"
        case .thai: return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        }
    }
}

struct RecognitionResult: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    let confidence: Double
    var previewData: Data?
    var detectedLanguage: String?
    var blocks: [OCRTextBlock]?
    var barcodes: [BarcodeResult]?
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         text: String,
         confidence: Double,
         preview: NSImage? = nil,
         detectedLanguage: String? = nil,
         blocks: [OCRTextBlock]? = nil,
         barcodes: [BarcodeResult]? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.confidence = confidence
        self.previewData = preview?.compactPreviewData
        self.detectedLanguage = detectedLanguage
        self.blocks = blocks
        self.barcodes = barcodes
    }
    
    var previewImage: NSImage? {
        guard let data = previewData else { return nil }
        return NSImage(data: data)
    }
}

extension NSImage {
    /// Компактное JPEG-представление превью (меньше, чем TIFF) — для хранения
    /// истории распознаваний на диске.
    var compactPreviewData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return tiffRepresentation
        }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) ?? tiffRepresentation
    }
}

// MARK: - AI Models (Full Implementation)

enum AIServiceProvider: String, CaseIterable, Identifiable, Codable {
    case deepseek = "DeepSeek"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case local = "Local (Ollama)"
    
    var id: String { rawValue }
    
    var baseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .local: return "http://localhost:11434"
        }
    }
    
    var modelName: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-4-5"
        case .local: return "llama3"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .deepseek: return ["deepseek-chat", "deepseek-coder"]
        case .openai: return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .anthropic: return ["claude-sonnet-4-5", "claude-opus-4-1", "claude-3-5-haiku-latest"]
        case .local: return ["llama3", "mistral", "codellama"]
        }
    }
}

enum AIOperation: String, CaseIterable, Identifiable, Codable {
    case rewrite = "rewrite"
    case improve = "improve"
    case summarize = "summarize"
    case translate = "translate"
    case fixGrammar = "grammar"
    case expand = "expand"
    case formal = "formal"
    case informal = "informal"
    case translateToRussian = "translate_ru"
    
    var id: String { rawValue }
    
    // Локализованное название для UI.
    // ВАЖНО: не переопределяем синтезированный `rawValue`, иначе ломаются
    // RawRepresentable, Codable и стабильность Identifiable.
    var title: String {
        switch self {
        case .rewrite: return SettingsManager.shared.t(.aiOpRewrite)
        case .improve: return SettingsManager.shared.t(.aiOpImprove)
        case .summarize: return SettingsManager.shared.t(.aiOpSummarize)
        case .translate: return SettingsManager.shared.t(.aiOpTranslate)
        case .fixGrammar: return SettingsManager.shared.t(.aiOpGrammar)
        case .expand: return SettingsManager.shared.t(.aiOpExpand)
        case .formal: return SettingsManager.shared.t(.aiOpFormal)
        case .informal: return SettingsManager.shared.t(.aiOpInformal)
        case .translateToRussian: return SettingsManager.shared.t(.aiOpTranslateRu)
        }
    }
    
    var icon: String {
        switch self {
        case .rewrite: return "pencil"
        case .improve: return "wand.and.stars"
        case .summarize: return "doc.text.below.ecg"
        case .translate, .translateToRussian: return "character.book.closed"
        case .fixGrammar: return "checkmark.circle"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .formal: return "briefcase"
        case .informal: return "message"
        }
    }
    
    var prompt: String {
        switch self {
        case .rewrite: return SettingsManager.shared.t(.aiPromptRewrite)
        case .improve: return SettingsManager.shared.t(.aiPromptImprove)
        case .summarize: return SettingsManager.shared.t(.aiPromptSummarize)
        case .translate: return SettingsManager.shared.t(.aiPromptTranslate)
        case .fixGrammar: return SettingsManager.shared.t(.aiPromptGrammar)
        case .expand: return SettingsManager.shared.t(.aiPromptExpand)
        case .formal: return SettingsManager.shared.t(.aiPromptFormal)
        case .informal: return SettingsManager.shared.t(.aiPromptInformal)
        case .translateToRussian: return SettingsManager.shared.t(.aiPromptTranslateRu)
        }
    }
}

struct AIConfig: Codable {
    var provider: AIServiceProvider = .deepseek {
        didSet {
            // При смене провайдера автоматически подставляем дефолтную модель.
            if provider != oldValue {
                model = provider.modelName
            }
        }
    }
    var apiKey: String = ""
    var model: String = "deepseek-chat"
    var temperature: Double = 0.7
    var maxTokens: Int = 2000
    var enabled: Bool = false
    
    static let `default` = AIConfig()
}

// Структуры для ответов API

struct AIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    struct Usage: Codable {
        let total_tokens: Int
    }
    
    let choices: [Choice]
    let usage: Usage?
}

struct OllamaResponse: Codable {
    let response: String
}

// Anthropic API Responses (Messages API v1)
struct AnthropicResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let content: [ContentBlock]
    let usage: Usage?
}

// Ошибки

enum AIError: LocalizedError {
    case configurationError(String)
    case emptyText
    case networkError(String)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationError(let msg):
            return "\(SettingsManager.shared.t(.aiErrConfig)) \(msg)"
        case .emptyText:
            return SettingsManager.shared.t(.aiErrEmpty)
        case .networkError(let msg):
            return "\(SettingsManager.shared.t(.aiErrNetwork)) \(msg)"
        case .apiError(let msg):
            return "\(SettingsManager.shared.t(.aiErrApi)) \(msg)"
        }
    }
}
