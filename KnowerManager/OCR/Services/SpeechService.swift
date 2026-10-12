import Foundation
import AVFoundation
import Combine

/// Озвучка распознанного текста через AVSpeechSynthesizer.
final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published var config: OCRTTSConfig

    /// Голоса, доступные для выбранного языка (или все, если язык не задан).
    @Published private(set) var availableVoices: [AVSpeechSynthesisVoice] = []

    private let synthesizer = AVSpeechSynthesizer()
    private static let configKey = "ocrTTSConfig"

    private override init() {
        self.config = Self.loadConfig()
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Публичный API

    func refreshVoices(languageCode: String?) {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let filtered: [AVSpeechSynthesisVoice]
        if let code = languageCode, !code.isEmpty {
            let base = code.lowercased()
            filtered = all.filter { $0.language.lowercased().hasPrefix(base) }
        } else {
            filtered = all
        }
        availableVoices = filtered.isEmpty ? all : filtered
    }

    /// Озвучивает текст. `languageCode` — базовый код (например, "ru").
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
        } else if let code = languageCode,
                  let voice = AVSpeechSynthesisVoice(language: code) {
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
