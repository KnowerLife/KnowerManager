import Foundation
@preconcurrency import Vision
import AppKit
import ImageIO

/// Результат одного прохода распознавания текста.
struct OCRRecognitionOutput {
    let text: String
    let averageConfidence: Double
    let blocks: [OCRTextBlock]

    static let empty = OCRRecognitionOutput(text: "", averageConfidence: 0, blocks: [])
}

class OCRService {

    // MARK: - Ограничение одиночного resume для continuation
    private final class OneShotGate: @unchecked Sendable {
        private let lock = NSLock()
        private var used = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if used { return false }
            used = true
            return true
        }
    }

    /// Последняя поддерживаемая ревизия движка распознавания.
    private var latestRevision: Int {
        if #available(macOS 13.0, *) { return VNRecognizeTextRequestRevision3 }
        return VNRecognizeTextRequestRevision2
    }

    // MARK: - Распознавание текста

    func recognizeText(in image: NSImage, options: OCROptions) async throws -> OCRRecognitionOutput {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        // Оставляем только языки, реально поддерживаемые выбранным уровнем и ревизией.
        let supported = Self.supportedLanguages(for: options.recognitionLevel, revision: latestRevision)
        var requested = options.languages.map { code in
            if let language = OCRLanguage(rawValue: code) { return language.visionCode }
            return code
        }
        requested = requested.filter { supported.isEmpty || supported.contains($0) }
        if requested.isEmpty { requested = ["en-US"] }

        return try await withCheckedThrowingContinuation { continuation in
            let gate = OneShotGate()
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    if gate.claim() { continuation.resume(throwing: error) }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    if gate.claim() { continuation.resume(returning: .empty) }
                    return
                }

                let blocks = Self.makeBlocks(from: observations)
                let text = blocks.map(\.text).joined(separator: "\n")
                let avg: Double
                if blocks.isEmpty {
                    avg = 0
                } else {
                    avg = blocks.reduce(0.0) { $0 + $1.confidence } / Double(blocks.count)
                }

                if gate.claim() {
                    continuation.resume(returning: OCRRecognitionOutput(text: text, averageConfidence: avg, blocks: blocks))
                }
            }

            request.recognitionLevel = options.recognitionLevel == .accurate ? .accurate : .fast
            request.usesLanguageCorrection = options.usesLanguageCorrection
            request.recognitionLanguages = requested
            if !options.customWords.isEmpty {
                request.customWords = options.customWords
            }
            if options.minimumTextHeight > 0 {
                request.minimumTextHeight = Float(options.minimumTextHeight)
            }
            if #available(macOS 13.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
                request.automaticallyDetectsLanguage = options.automaticallyDetectsLanguage
            }

            let handler = VNImageRequestHandler(cgImage: cgImage,
                                                orientation: options.imageOrientation.cgOrientation,
                                                options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    if gate.claim() { continuation.resume(throwing: error) }
                }
            }
        }
    }

    // MARK: - Штрих-коды и QR

    func detectBarcodes(in image: NSImage) async throws -> [BarcodeResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let gate = OneShotGate()
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    if gate.claim() { continuation.resume(throwing: error) }
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    if gate.claim() { continuation.resume(returning: []) }
                    return
                }

                let results: [BarcodeResult] = observations.compactMap { observation in
                    guard let value = observation.payloadStringValue else { return nil }
                    return BarcodeResult(value: value,
                                         symbology: observation.symbology.rawValue,
                                         rect: observation.boundingBox)
                }

                if gate.claim() { continuation.resume(returning: results) }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    if gate.claim() { continuation.resume(throwing: error) }
                }
            }
        }
    }

    // MARK: - Поддерживаемые языки

    static func supportedLanguages(for level: OCRRecognitionLevel, revision: Int) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level == .accurate ? .accurate : .fast
        request.revision = revision
        var languages = (try? request.supportedRecognitionLanguages()) ?? []
        if languages.isEmpty {
            languages = ["en-US"]
        }
        return languages
    }

    /// Список языков приложения, реально поддерживаемых Vision на этой машине.
    static func availableOCRLanguages() -> [OCRLanguage] {
        let supported = supportedLanguages(for: .accurate, revision: 3)
        return OCRLanguage.allCases.filter { language in
            supported.contains { $0.caseInsensitiveCompare(language.visionCode) == .orderedSame }
        }
    }

    // MARK: - Вспомогательное

    private static func makeBlocks(from observations: [VNRecognizedTextObservation]) -> [OCRTextBlock] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRTextBlock(text: candidate.string,
                                confidence: Double(candidate.confidence),
                                rect: observation.boundingBox)
        }
    }
}

enum OCRError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return SettingsManager.shared.t(.ocrErrImage)
        }
    }
}
