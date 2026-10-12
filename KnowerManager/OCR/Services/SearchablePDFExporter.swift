import Foundation
import AppKit
import CoreText

/// Экспорт отсканированных страниц в PDF с невидимым текстовым слоем.
///
/// Изображение страницы рисуется как обычно, а поверх него — «невидимый» текст
/// (режим рисования `.invisible`). Визуально это исходное изображение, но такой
/// PDF можно искать и выделять текст (Preview, PDFKit, Spotlight).
///
/// Используется Core Graphics (`CGContext` для PDF) + Core Text, а не
/// `PDFAnnotation(.freeText)`, потому что аннотации не попадают в текстовый
/// слой документа и не находятся поиском.
enum SearchablePDFExporter {

    struct Page {
        let image: NSImage
        let blocks: [OCRTextBlock]
    }

    // MARK: - Экспорт

    /// Создаёт PDF и сохраняет его по указанному URL.
    static func export(pages: [Page], to url: URL) throws {
        guard !pages.isEmpty else { throw OCRError.imageConversionFailed }

        // Базовый размер документа — по первой странице. Отдельные страницы
        // могут переопределить его через kCGPDFContextMediaBox (см. ниже).
        var baseBox = CGRect(origin: .zero, size: pageSize(for: pages[0].image))
        guard let ctx = CGContext(url as CFURL, mediaBox: &baseBox, nil) else {
            throw NSError(domain: "SearchablePDFExporter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: SettingsManager.shared.t(.ocrExportError)])
        }

        for page in pages {
            let size = pageSize(for: page.image)
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: mediaBoxData(CGRect(origin: .zero, size: size))
            ]
            ctx.beginPDFPage(pageInfo as CFDictionary)

            drawImage(page.image, in: ctx, size: size)
            drawText(page.blocks, in: ctx, size: size)

            ctx.endPDFPage()
        }

        ctx.closePDF()
    }

    /// Рендерит одну страницу в шаблон экспорта.
    static func pages(from scanPages: [OCRPage]) -> [Page] {
        scanPages.map { Page(image: $0.image, blocks: $0.blocks) }
    }

    // MARK: - Рисование

    private static func drawImage(_ image: NSImage, in ctx: CGContext, size: CGSize) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              size.width > 0, size.height > 0 else { return }

        // CGContext имеет origin снизу-слева, а изображения рисуем сверху-вниз,
        // поэтому временно переворачиваем систему координат по вертикали.
        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
        ctx.restoreGState()
    }

    private static func drawText(_ blocks: [OCRTextBlock], in ctx: CGContext, size: CGSize) {
        guard !blocks.isEmpty else { return }
        ctx.setTextDrawingMode(.invisible)

        for block in blocks {
            // Vision отдаёт нормализованные координаты с origin снизу слева —
            // совпадает с системой координат PDF-страницы.
            let rect = CGRect(
                x: block.rect.minX * size.width,
                y: block.rect.minY * size.height,
                width: max(block.rect.width * size.width, 1),
                height: max(block.rect.height * size.height, 1)
            )

            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let fontSize = max(rect.height * 0.8, 1)
            let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
                ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributed)

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

            // Горизонтально подгоняем строку под ширину исходного блока,
            // чтобы выделение мышью совпадало с рамкой распознавания.
            let scaleX = lineWidth > 0 ? min(1, rect.width / lineWidth) : 1

            ctx.textMatrix = CGAffineTransform(scaleX: scaleX, y: 1)
            ctx.textPosition = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15)
            CTLineDraw(line, ctx)
        }
    }

    // MARK: - Вспомогательное

    /// Размер страницы в пунктах берём из размера изображения (1 pt = 1 px).
    private static func pageSize(for image: NSImage) -> CGSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return CGSize(width: 595, height: 842) }
        return size
    }

    /// kCGPDFContextMediaBox ожидает CFData, внутри которого лежит CGRect.
    private static func mediaBoxData(_ rect: CGRect) -> CFData {
        var rect = rect
        return withUnsafeBytes(of: &rect) { buffer in
            CFDataCreate(nil, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count)!
        }
    }
}
