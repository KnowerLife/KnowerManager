import Foundation
import AppKit

// MARK: - OCR Models

enum OCRLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return SettingsManager.shared.t(.langRu)
        case .english: return SettingsManager.shared.t(.langEn)
        case .german: return SettingsManager.shared.t(.langDe)
        case .french: return SettingsManager.shared.t(.langFr)
        case .spanish: return SettingsManager.shared.t(.langEs)
        }
    }
}

struct RecognitionResult: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    let confidence: Double
    var previewData: Data?
    
    init(id: UUID = UUID(), date: Date = Date(), text: String, confidence: Double, preview: NSImage? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.confidence = confidence
        self.previewData = preview?.tiffRepresentation
    }
    
    var previewImage: NSImage? {
        guard let data = previewData else { return nil }
        return NSImage(data: data)
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
        case .openai: return "gpt-3.5-turbo"
        case .anthropic: return "claude-3-sonnet"
        case .local: return "llama3"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .deepseek: return ["deepseek-chat", "deepseek-coder"]
        case .openai: return ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo"]
        case .anthropic: return ["claude-3-haiku", "claude-3-sonnet", "claude-3-opus"]
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
    var provider: AIServiceProvider = .deepseek
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
