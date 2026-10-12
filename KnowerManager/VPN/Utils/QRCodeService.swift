import AppKit
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
@preconcurrency import Vision

// MARK: - Генерация и распознавание QR-кодов

enum QRCodeService {

    /// Генерирует NSImage с QR-кодом для строки (share-ссылка протокола).
    static func generate(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        guard let data = string.data(using: .utf8) else { return nil }
        filter.message = data
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }
        // Масштабируем, чтобы QR был чётким на Retina.
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = output.transformed(by: transform)

        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    /// Декодирует все QR-коды на изображении. Возвращает строки-нагрузки.
    static func decode(in image: NSImage) async -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let request = VNDetectBarcodesRequest { request, _ in
                guard !hasResumed else { return }
                hasResumed = true
                let results = (request.results as? [VNBarcodeObservation])?
                    .compactMap { $0.payloadStringValue } ?? []
                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }

    /// Извлекает NSImage из буфера обмена (поддержка PNG/JPEG/TIFF).
    static func imageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        for type in [NSPasteboard.PasteboardType.png,
                     NSPasteboard.PasteboardType.tiff] {
            if let data = pasteboard.data(forType: type) {
                return NSImage(data: data)
            }
        }
        // JPEG может лежать под типом .jpeg (UIKit-стиль) или в common-типах.
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            return NSImage(data: data)
        }
        return nil
    }

    /// Сохраняет QR как PNG в выбранное пользователем место.
    static func saveAsPNG(_ image: NSImage, suggestedName: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.png]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? png.write(to: url, options: .atomic)
        }
    }
}