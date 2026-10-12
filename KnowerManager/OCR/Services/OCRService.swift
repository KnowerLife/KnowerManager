import Foundation
@preconcurrency import Vision
import AppKit

class OCRService {
    func recognizeText(from image: NSImage, language: OCRLanguage, confidence: Double) async throws -> (text: String, confidence: Double) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось создать CGImage"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ("", 0))
                    return
                }
                
                // Извлекаем текст
                let recognizedStrings = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.string
                }
                
                let text = recognizedStrings.joined(separator: "\n")
                
                // Рассчитываем среднюю уверенность
                let confidences = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.confidence
                }
                
                let avgConfidence: Double
                if confidences.isEmpty {
                    avgConfidence = 0
                } else {
                    // Преобразуем VNConfidence (Float) в Double для вычислений
                    let totalConfidence = confidences.reduce(0.0) { result, confidence in
                        return result + Double(confidence)
                    }
                    avgConfidence = totalConfidence / Double(confidences.count)
                }
                
                continuation.resume(returning: (text, avgConfidence))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [language.rawValue, "en"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
