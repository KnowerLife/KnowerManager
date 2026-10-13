import Foundation
import AVFoundation
import Combine

/// Язык, для которого есть хотя бы один голос синтезатора.
struct SpeechLanguage: Identifiable, Equatable {
    let code: String
    let name: String
    var id: String { code }
}

/// Озвучка распознанного текста через AVSpeechSynthesizer.
final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published var config: OCRTTSConfig

    /// Голоса, доступные для выбранного языка (или все, если язык не задан).
    @Published private(set) var availableVoices: [AVSpeechSynthesisVoice] = []

    /// Языки, для которых есть хотя бы один голос синтезатора.
    @Published private(set) var availableLanguages: [SpeechLanguage] = []

    private let synthesizer = AVSpeechSynthesizer()
    private static let configKey = "ocrTTSConfig"

    private override init() {
        self.config = Self.loadConfig()
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Публичный API

    func refreshVoices(languageCode: String?) {
        availableVoices = voices(for: languageCode)
    }

    /// Голоса для языка (или все, если язык не задан / голосов не нашлось).
    func voices(for languageCode: String?) -> [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        guard let code = languageCode, !code.isEmpty else { return all }
        let base = code.lowercased()
        let filtered = all.filter { $0.language.lowercased().hasPrefix(base) }
        return filtered.isEmpty ? all : filtered
    }

    /// Список языков, доступных для озвучки (по установленным голосам).
    func refreshLanguages() {
        let codes = Set(AVSpeechSynthesisVoice.speechVoices().compactMap { voice in
            voice.language.split(separator: "-").first.map(String.init)
        })
        availableLanguages = codes.map { code in
            let name = OCRLanguage(rawValue: code)?.displayName
                ?? Locale.current.localizedString(forLanguageCode: code)?.capitalized
                ?? code.uppercased()
            return SpeechLanguage(code: code, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Задаёт язык озвучки. `nil` — брать язык из текста.
    func setLanguage(_ code: String?) {
        config.languageCode = code
        // Если выбранный голос не относится к новому языку — сбрасываем его.
        if let id = config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id),
           let code,
           !voice.language.lowercased().hasPrefix(code.lowercased()) {
            config.voiceIdentifier = nil
        }
        saveConfig()
        refreshVoices(languageCode: code)
    }

    /// Первый подходящий голос для языка (учитывает базовый код без региона).
    private static func voice(forLanguage code: String) -> AVSpeechSynthesisVoice? {
        if let voice = AVSpeechSynthesisVoice(language: code) { return voice }
        let base = code.lowercased()
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.lowercased().hasPrefix(base) }
    }

    /// Озвучивает текст. Язык берётся из настроек озвучки, иначе из `languageCode`.
    func speak(_ text: String, languageCode: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitch
        utterance.volume = config.volume

        if let identifier = config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else if let code = config.languageCode ?? languageCode,
                  let voice = Self.voice(forLanguage: code) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }

        synthesizer.speak(utterance)
    }

    func pause() {
        guard synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
    }

    func stop() {
        guard synthesizer.isSpeaking || synthesizer.isPaused else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.configKey)
        }
    }

    private static func loadConfig() -> OCRTTSConfig {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(OCRTTSConfig.self, from: data) {
            return decoded
        }
        return .default
    }

    private func updateState() {
        DispatchQueue.main.async {
            self.isSpeaking = self.synthesizer.isSpeaking
            self.isPaused = self.synthesizer.isPaused
        }
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        updateState()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        updateState()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        updateState()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        updateState()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        updateState()
    }
}
