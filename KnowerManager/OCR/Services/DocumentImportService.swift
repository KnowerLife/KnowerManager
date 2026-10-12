import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Одна импортированная страница (из изображения или PDF).
struct ImportedPage {
    let image: NSImage
    let embeddedText: String?
    let title: String
}

/// Загрузка изображений и PDF-документов для распознавания.
final class DocumentImportService {

    /// Типы файлов, которые можно открыть в сканере.
    static var supportedContentTypes: [UTType] {
        [.image, .pdf]
    }

    func loadPages(from urls: [URL], preferEmbeddedPDFText: Bool) -> [ImportedPage] {
        var pages: [ImportedPage] = []
        for url in urls {
            if url.pathExtension.lowercased() == "pdf" {
                pages.append(contentsOf: loadPDF(from: url, preferEmbeddedText: preferEmbeddedPDFText))
            } else if let image = NSImage(contentsOf: url) {
                pages.append(ImportedPage(image: image, embeddedText: nil, title: url.lastPathComponent))
            }
        }
        return pages
    }

    func loadImages(from urls: [URL]) -> [NSImage] {
        urls.compactMap { NSImage(contentsOf: $0) }
    }

    // MARK: - PDF

    func loadPDF(from url: URL, preferEmbeddedText: Bool) -> [ImportedPage] {
        guard let document = PDFDocument(url: url) else { return [] }
        let name = url.deletingPathExtension().lastPathComponent
        var pages: [ImportedPage] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }

            // Ограничиваем длинную сторону ~2200px — компромисс между качеством OCR и памятью.
            let maxDimension: CGFloat = 2200
            let scale = min(maxDimension / max(bounds.width, bounds.height), 3.0)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            let image = page.thumbnail(of: size, for: .mediaBox)

            var embedded: String? = preferEmbeddedText ? page.string : nil
            if let text = embedded, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                embedded = nil
            }

            pages.append(ImportedPage(image: image,
                                      embeddedText: embedded,
                                      title: "\(name) · \(index + 1)"))
        }
        return pages
    }

    /// Есть ли в PDF встроенный текстовый слой (без рендеринга). Быстрая проверка первой страницы.
    func pdfHasEmbeddedText(_ url: URL) -> Bool {
        guard let document = PDFDocument(url: url), let first = document.page(at: 0) else { return false }
        let text = first.string ?? ""
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
