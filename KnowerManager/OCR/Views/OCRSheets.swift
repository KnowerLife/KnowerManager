import SwiftUI
import AppKit
import AVFAudio

// MARK: - Общие элементы листов

private struct OCRSheetHeader: View {
    let title: String
    let icon: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.blue)
            Text(title).font(.headline)
            Spacer()
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
    }
}

private struct OCRToggleRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isOn ? color : .secondary)
                .frame(width: 22)
            Text(title).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(color)
        }
    }
}

private struct OCRSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(valueText).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
            if let step = step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }
}

private struct OCRSectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Тонкая настройка распознавания

struct OCRAdvancedSettingsSheet: View {
    @ObservedObject var ocrManager: OCRManager
    @ObservedObject var settings: SettingsManager
    @Environment(\.presentationMode) private var presentationMode

    private var customWordsBinding: Binding<String> {
        Binding(
            get: { ocrManager.ocrOptions.customWords.joined(separator: ", ") },
            set: { text in
                ocrManager.ocrOptions.customWords = text
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var availableLanguages: [OCRLanguage] {
        let supported = OCRService.availableOCRLanguages()
        return supported.isEmpty ? OCRLanguage.allCases : supported
    }

    var body: some View {
        VStack(spacing: 0) {
            OCRSheetHeader(title: settings.t(.ocrAdvanced), icon: "slider.horizontal.3") {
                presentationMode.wrappedValue.dismiss()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    OCRSectionTitle(text: settings.t(.ocrRecognition))

                    Picker("", selection: $ocrManager.ocrOptions.recognitionLevel) {
                        ForEach(OCRRecognitionLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    OCRToggleRow(title: settings.t(.ocrLanguageCorrection),
                                 icon: "textformat.abc",
                                 color: .blue,
                                 isOn: $ocrManager.ocrOptions.usesLanguageCorrection)

                    OCRToggleRow(title: settings.t(.ocrAutoDetect),
                                 icon: "globe",
                                 color: .purple,
                                 isOn: $ocrManager.ocrOptions.automaticallyDetectsLanguage)

                    OCRToggleRow(title: settings.t(.ocrDetectBarcodes),
                                 icon: "barcode.viewfinder",
                                 color: .green,
                                 isOn: $ocrManager.ocrOptions.detectBarcodes)

                    OCRToggleRow(title: settings.t(.ocrShowBoxes),
                                 icon: "rectangle.dashed",
                                 color: .teal,
                                 isOn: $ocrManager.ocrOptions.keepTextBlocks)

                    OCRToggleRow(title: settings.t(.ocrPreferEmbeddedPDF),
                                 icon: "doc.richtext",
                                 color: .orange,
                                 isOn: $ocrManager.ocrOptions.preferEmbeddedPDFText)

                    OCRSliderRow(title: settings.t(.ocrMinTextHeight),
                                 valueText: String(format: "%.1f%%", ocrManager.ocrOptions.minimumTextHeight * 100),
                                 value: $ocrManager.ocrOptions.minimumTextHeight,
                                 range: 0...0.1,
                                 step: 0.005)

                    Divider()

                    OCRSectionTitle(text: settings.t(.ocrImageOrientation))
                    Picker("", selection: $ocrManager.ocrOptions.imageOrientation) {
                        ForEach(OCRImageOrientation.allCases) { orientation in
                            Text(orientation.displayName).tag(orientation)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Divider()

                    OCRSectionTitle(text: settings.t(.ocrCustomWords))
                    TextField(settings.t(.ocrCustomWordsPlaceholder), text: customWordsBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Divider()

                    OCRSectionTitle(text: settings.t(.ocrLanguages))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(availableLanguages) { lang in
                            LanguageChip(language: lang,
                                         isSelected: ocrManager.ocrOptions.languages.contains(lang.rawValue)) {
                                toggle(lang)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button(settings.t(.ocrReset)) {
                    ocrManager.ocrOptions = .default
                }
                .buttonStyle(ModernButtonStyle(color: .gray, variant: .ghost))

                Spacer()

                Button(settings.t(.btnDone)) {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(color: .blue))
            }
            .padding(16)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ language: OCRLanguage) {
        var list = ocrManager.ocrOptions.languages
        if let index = list.firstIndex(of: language.rawValue) {
            if list.count > 1 { list.remove(at: index) }
        } else {
            list.append(language.rawValue)
        }
        ocrManager.ocrOptions.languages = list
    }
}

private struct LanguageChip: View {
    let language: OCRLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(language.flag)
                Text(language.displayName).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Улучшение изображения

struct OCREnhanceSheet: View {
    @ObservedObject var ocrManager: OCRManager
    @ObservedObject var settings: SettingsManager
    @Environment(\.presentationMode) private var presentationMode

    @State private var thumbnail: NSImage?
    @State private var preview: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            OCRSheetHeader(title: settings.t(.ocrEnhance), icon: "wand.and.stars") {
                presentationMode.wrappedValue.dismiss()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text(settings.t(.previewLabel)).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            if let image = thumbnail {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                    .frame(height: 120).background(Color.black.opacity(0.05)).cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05))
                                    .frame(height: 120).overlay(Image(systemName: "photo").foregroundColor(.secondary))
                            }
                        }
                        Image(systemName: "arrow.right").foregroundColor(.secondary)
                        VStack(spacing: 4) {
                            Text(settings.t(.ocrEnhance)).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                            if let image = preview {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                    .frame(height: 120).background(Color.black.opacity(0.05)).cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05))
                                    .frame(height: 120).overlay(Image(systemName: "wand.and.stars").foregroundColor(.secondary))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    OCRToggleRow(title: settings.t(.ocrEnhanceEnabled),
                                 icon: "wand.and.stars", color: .green,
                                 isOn: $ocrManager.preprocessingOptions.isEnabled)

                    Divider()

                    OCRToggleRow(title: settings.t(.ocrGrayscale),
                                 icon: "circle.lefthalf.filled", color: .gray,
                                 isOn: $ocrManager.preprocessingOptions.grayscale)

                    OCRToggleRow(title: settings.t(.ocrInvert),
                                 icon: "circle.righthalf.filled", color: .indigo,
                                 isOn: $ocrManager.preprocessingOptions.invert)

                    OCRToggleRow(title: settings.t(.ocrBinarize),
                                 icon: "circle.hexagongrid.fill", color: .black,
                                 isOn: $ocrManager.preprocessingOptions.binarize)

                    OCRSliderRow(title: settings.t(.ocrContrast),
                                 valueText: String(format: "%.2f", ocrManager.preprocessingOptions.contrast),
                                 value: $ocrManager.preprocessingOptions.contrast,
                                 range: 0.5...2.0, step: 0.05)

                    OCRSliderRow(title: settings.t(.ocrBrightness),
                                 valueText: String(format: "%.2f", ocrManager.preprocessingOptions.brightness),
                                 value: $ocrManager.preprocessingOptions.brightness,
                                 range: -0.5...0.5, step: 0.05)

                    OCRSliderRow(title: settings.t(.ocrSharpness),
                                 valueText: String(format: "%.2f", ocrManager.preprocessingOptions.sharpness),
                                 value: $ocrManager.preprocessingOptions.sharpness,
                                 range: 0...2.0, step: 0.1)

                    OCRSliderRow(title: settings.t(.ocrUpscale),
                                 valueText: String(format: "%.1fx", ocrManager.preprocessingOptions.upscale),
                                 value: $ocrManager.preprocessingOptions.upscale,
                                 range: 1.0...3.0, step: 0.1)

                    if ocrManager.preprocessingOptions.binarize {
                        OCRSliderRow(title: settings.t(.ocrBinarizeThreshold),
                                     valueText: String(format: "%.2f", ocrManager.preprocessingOptions.binarizeThreshold),
                                     value: $ocrManager.preprocessingOptions.binarizeThreshold,
                                     range: 0.1...0.9, step: 0.05)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button(settings.t(.ocrReset)) {
                    ocrManager.preprocessingOptions = .default
                }
                .buttonStyle(ModernButtonStyle(color: .gray, variant: .ghost))

                Spacer()

                Button(settings.t(.btnDone)) {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ModernButtonStyle(color: .blue))
            }
            .padding(16)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: buildThumbnail)
        .onChange(of: ocrManager.preprocessingOptions) { _ in updatePreview() }
    }

    private func buildThumbnail() {
        guard let base = ocrManager.currentImage else { thumbnail = nil; preview = nil; return }
        thumbnail = OCREnhanceSheet.downscale(base, maxDimension: 400)
        updatePreview()
    }

    private func updatePreview() {
        guard let thumb = thumbnail else { preview = nil; return }
        preview = ImagePreprocessor().process(thumb, options: ocrManager.preprocessingOptions)
    }

    static func downscale(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension, size.width > 0, size.height > 0 else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }
}

// MARK: - Озвучка

struct OCRTTSSheet: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var speech = SpeechService.shared
    @ObservedObject var ocrManager = OCRManager.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            OCRSheetHeader(title: settings.t(.ocrTTSSettings), icon: "speaker.wave.2") {
                speech.stop()
                presentationMode.wrappedValue.dismiss()
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(settings.t(.ocrTTSVoice)).font(.system(size: 12, weight: .semibold))

                Picker("", selection: Binding(
                    get: { speech.config.voiceIdentifier ?? "" },
                    set: { speech.config.voiceIdentifier = $0.isEmpty ? nil : $0; speech.saveConfig() }
                )) {
                    Text("Default").tag("")
                    ForEach(speech.availableVoices, id: \.identifier) { voice in
                        Text("\(voice.name) — \(voice.language)").tag(voice.identifier)
                    }
                }
                .labelsHidden()
                .frame(maxHeight: 160)

                OCRSliderRow(title: settings.t(.ocrTTSRate),
                             valueText: String(format: "%.2f", speech.config.rate),
                             value: Binding(
                                get: { Double(speech.config.rate) },
                                set: { speech.config.rate = Float($0); speech.saveConfig() }
                             ),
                             range: 0.3...0.8, step: 0.05)

                HStack(spacing: 10) {
                    if speech.isSpeaking {
                        Button(settings.t(.ocrPauseSpeak)) { speech.isPaused ? speech.resume() : speech.pause() }
                            .buttonStyle(ModernButtonStyle(color: .orange, variant: .outline))
                        Button(settings.t(.ocrStopSpeak)) { speech.stop() }
                            .buttonStyle(ModernButtonStyle(color: .red, variant: .outline))
                    } else {
                        Button(settings.t(.ocrSpeak)) { ocrManager.speakActivePage() }
                            .buttonStyle(ModernButtonStyle(color: .blue))
                            .disabled(ocrManager.recognizedText.isEmpty)
                    }
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            let code = ocrManager.detectedLanguage?.code ?? ocrManager.ocrOptions.languages.first
            speech.refreshVoices(languageCode: code)
        }
    }
}

// MARK: - Сканер

struct OCRScannerSheet: View {
    @ObservedObject var settings: SettingsManager
    var onScan: (NSImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var lastError: String?

    var body: some View {
        VStack(spacing: 0) {
            OCRSheetHeader(title: settings.t(.ocrImportScannerTitle), icon: "scanner") {
                presentationMode.wrappedValue.dismiss()
            }

            VStack(spacing: 8) {
                Text(settings.t(.ocrScannerHint))
                    .font(.system(size: 11)).foregroundColor(.secondary)

                ScannerDeviceView(onScan: { image in
                    lastError = nil
                    onScan(image)
                }, onError: { error in
                    lastError = error.localizedDescription
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let error = lastError {
                    Text(error).font(.system(size: 10)).foregroundColor(.red).lineLimit(2)
                }
            }
            .padding(12)

            HStack {
                Spacer()
                Button(settings.t(.ocrScannerClose)) { presentationMode.wrappedValue.dismiss() }
                    .buttonStyle(ModernButtonStyle(color: .blue))
            }
            .padding(12)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
        }
        .frame(width: 520, height: 560)
    }
}
