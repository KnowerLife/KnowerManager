import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Улучшение изображения перед OCR с помощью Core Image.
/// Все преобразования (кроме масштабирования) сохраняют геометрию,
/// поэтому нормализованные рамки распознанного текста остаются валидными.
final class ImagePreprocessor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Применяет пайплайн предобработки. Если опции «пустые» — возвращает исходник.
    func process(_ image: NSImage, options: ImagePreprocessingOptions) -> NSImage {
        guard !options.isIdentity else { return image }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        var ciImage = CIImage(cgImage: cgImage)

        // 1. Увеличение (Lanczos) — помогает на мелком тексте.
        if options.upscale > 1.001 {
            let scale = CIFilter.lanczosScaleTransform()
            scale.inputImage = ciImage
            scale.scale = Float(options.upscale)
            scale.aspectRatio = 1.0
            if let output = scale.outputImage { ciImage = output }
        }

        // 2. Яркость/контраст/насыщенность.
        let controls = CIFilter.colorControls()
        controls.inputImage = ciImage
        controls.brightness = Float(options.brightness)
        controls.contrast = Float(options.contrast)
        controls.saturation = options.grayscale ? 0.0 : 1.0
        if let output = controls.outputImage { ciImage = output }

        // 3. Резкость.
        if options.sharpness > 0.001 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = ciImage
            sharpen.sharpness = Float(options.sharpness)
            if let output = sharpen.outputImage { ciImage = output }
        }

        // 4. Инверсия (для тёмных скриншотов с белым текстом).
        if options.invert {
            let invert = CIFilter.colorInvert()
            invert.inputImage = ciImage
            if let output = invert.outputImage { ciImage = output }
        }

        // 5. Бинаризация — чёрное/белое по порогу.
        if options.binarize {
            let threshold = CIFilter.colorThreshold()
            threshold.inputImage = ciImage
            threshold.threshold = Float(options.binarizeThreshold)
            if let output = threshold.outputImage { ciImage = output }
        }

        guard let outputCG = context.createCGImage(ciImage, from: ciImage.extent) else {
            return image
        }
        return NSImage(cgImage: outputCG, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
