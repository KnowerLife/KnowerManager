import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - SCANNER VIEW (OCR)

struct ScannerView: View {
    @ObservedObject var ocrManager: OCRManager
    @ObservedObject var settings: SettingsManager
    @ObservedObject var speech = SpeechService.shared

    @State private var showAISettings = false
    @State private var showAdvanced = false
    @State private var showEnhance = false
    @State private var showImport = false
    @State private var showScanner = false
    @State private var showTTS = false
    @State private var showFileImporter = false
    @State private var isDropTargeted = false
    @State private var historySearchText = ""

    private var isBusy: Bool { ocrManager.isProcessing || ocrManager.isAIProcessing }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                controlPanel
                pagesStrip
                historyStrip
                previewCard
                barcodesCard
                textEditorCard
                Spacer().frame(height: 40)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(dropHighlight)
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { handleDrop($0) }
        .sheet(isPresented: $showAISettings) { AIConfigSheet(ocrManager: ocrManager) }
        .sheet(isPresented: $showAdvanced) { OCRAdvancedSettingsSheet(ocrManager: ocrManager, settings: settings) }
        .sheet(isPresented: $showEnhance) { OCREnhanceSheet(ocrManager: ocrManager, settings: settings) }
        .sheet(isPresented: $showScanner) {
            OCRScannerSheet(settings: settings) { image in
                ocrManager.importFromScanner(image)
            }
        }
        .sheet(isPresented: $showTTS) { OCRTTSSheet(settings: settings) }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: DocumentImportService.supportedContentTypes,
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                ocrManager.importURLs(urls)
            }
        }
    }

    // MARK: - Панель управления

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "viewfinder.circle.fill").font(.title3).foregroundColor(.blue)
                Text(settings.t(.ocrTitle)).font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                if isBusy {
                    ProgressView().scaleEffect(0.5)
                } else {
                    Text(ocrManager.statusMessage).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Divider().background(Color.secondary.opacity(0.1))

            // Захват экрана
            HStack(spacing: 8) {
                Button(action: { ocrManager.captureArea() }) {
                    Label(settings.t(.ocrArea), systemImage: "crop")
                }
                .buttonStyle(ModernButtonStyle(color: .blue)).disabled(isBusy)

                Button(action: { ocrManager.captureScreen() }) { Image(systemName: "macwindow") }
                    .buttonStyle(ModernButtonStyle(color: .secondary)).frame(width: 40)
                    .help(settings.t(.ocrScreen))

                Button(action: { ocrManager.pasteFromClipboard() }) { Image(systemName: "doc.on.clipboard") }
                    .buttonStyle(ModernButtonStyle(color: .secondary)).frame(width: 40)
                    .help(settings.t(.ocrClipboard))
            }
            .disabled(isBusy)

            // Импорт / экспорт
            HStack(spacing: 8) {
                Menu {
                    Button { showFileImporter = true } label: { Label(settings.t(.ocrImportFiles), systemImage: "photo.on.rectangle") }
                    Button { showFileImporter = true } label: { Label(settings.t(.ocrImportPDF), systemImage: "doc.richtext") }
                    Button { showScanner = true } label: { Label(settings.t(.ocrImportScannerTitle), systemImage: "scanner") }
                } label: {
                    Label(settings.t(.ocrImport), systemImage: "square.and.arrow.down")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(isBusy)

                Menu {
                    ForEach(OCRExportFormat.allCases) { format in
                        Button { ocrManager.export(as: format) } label: { Label(format.displayName, systemImage: format.icon) }
                    }
                } label: {
                    Label(settings.t(.ocrExport), systemImage: "square.and.arrow.up.on.square")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .disabled(ocrManager.pages.isEmpty)

                Spacer()

                Button(action: { showAdvanced = true }) {
                    HStack(spacing: 4) { Image(systemName: "slider.horizontal.3"); Text(settings.t(.ocrAdvanced)) }
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle()).foregroundColor(.secondary)
            }

            // Языки и вторичные действия
            HStack(spacing: 8) {
                languageMenu
                Spacer()
                Button(action: { showEnhance = true }) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundColor(ocrManager.preprocessingOptions.isEnabled ? .green : .secondary)
                }
                .buttonStyle(PlainButtonStyle()).help(settings.t(.ocrEnhance))

                Button(action: { showAISettings = true }) {
                    HStack(spacing: 4) { Image(systemName: "brain.head.profile"); Text("AI") }
                        .font(.system(size: 11)).foregroundColor(ocrManager.aiService.config.enabled ? .purple : .secondary)
                }.buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10).background(DesignSystem.cardColor).cornerRadius(DesignSystem.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius).stroke(DesignSystem.strokeColor, lineWidth: 1))
    }

    private var languageMenu: some View {
        let selected = ocrManager.ocrOptions.languages
        return Menu {
            ForEach(availableLanguages) { lang in
                Button {
                    toggleLanguage(lang)
                } label: {
                    HStack {
                        Text("\(lang.flag) \(lang.displayName)")
                        if selected.contains(lang.rawValue) { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "character.book.closed")
                Text(languageSummary).font(.system(size: 11)).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.black.opacity(0.05)).cornerRadius(6)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .disabled(isBusy)
    }

    private var availableLanguages: [OCRLanguage] {
        let supported = OCRService.availableOCRLanguages()
        return supported.isEmpty ? OCRLanguage.allCases : supported
    }

    private var languageSummary: String {
        let names = ocrManager.ocrOptions.languages.compactMap { OCRLanguage(rawValue: $0)?.displayName }
        if names.isEmpty { return settings.t(.ocrLanguages) }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }

    private func toggleLanguage(_ language: OCRLanguage) {
        var list = ocrManager.ocrOptions.languages
        if let index = list.firstIndex(of: language.rawValue) {
            if list.count > 1 { list.remove(at: index) }
        } else {
            list.append(language.rawValue)
        }
        ocrManager.ocrOptions.languages = list
    }

    // MARK: - Язык текста у результата

    /// Бейдж языка распознанного текста. По нажатию — меню, где можно вручную
    /// задать язык текста (влияет на бейдж и озвучку) или вернуть автоопределение.
    private var languageBadge: some View {
        let current = ocrManager.detectedLanguage?.code
        return Menu {
            Button {
                ocrManager.setTextLanguage(nil)
            } label: {
                HStack {
                    Text(settings.t(.ocrAutoDetect))
                    if !ocrManager.isTextLanguageManual { Image(systemName: "checkmark") }
                }
            }
            Divider()
            ForEach(availableLanguages) { lang in
                Button {
                    ocrManager.setTextLanguage(lang.rawValue)
                } label: {
                    HStack {
                        Text("\(lang.flag) \(lang.displayName)")
                        if ocrManager.isTextLanguageManual && current == lang.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(ocrManager.detectedLanguage?.displayName ?? settings.t(.ocrLang))
                Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.blue.opacity(0.12)).foregroundColor(.blue)
            .cornerRadius(4)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .fixedSize()
        .disabled(ocrManager.recognizedText.isEmpty)
    }

    // MARK: - Страницы

    @ViewBuilder
    private var pagesStrip: some View {
        if ocrManager.pages.count > 1 {
            HStack(spacing: 8) {
                Text(settings.t(.ocrPages)).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Spacer()
                Button(action: { ocrManager.previousPage() }) { Image(systemName: "chevron.left") }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(ocrManager.activePageIndex == 0)
                Text("\(ocrManager.activePageIndex + 1) / \(ocrManager.pages.count)")
                    .font(.system(size: 10, design: .monospaced))
                Button(action: { ocrManager.nextPage() }) { Image(systemName: "chevron.right") }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(ocrManager.activePageIndex >= ocrManager.pages.count - 1)
                Button(action: { ocrManager.removeActivePage() }) { Image(systemName: "trash") }
                    .buttonStyle(PlainButtonStyle()).foregroundColor(.secondary)
                    .help(settings.t(.ocrRemovePage))
            }
            .padding(.horizontal, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(ocrManager.pages.enumerated()), id: \.element.id) { index, page in
                        PageThumbnail(page: page, index: index, isActive: index == ocrManager.activePageIndex)
                            .onTapGesture { ocrManager.setActivePage(index) }
                    }
                }.padding(4)
            }
            .frame(height: 60)
        }
    }

    @ViewBuilder
    private var historyStrip: some View {
        if !ocrManager.recognitionHistory.isEmpty {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                    TextField(settings.t(.ocrSearchHistoryPlaceholder), text: $historySearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                    if !historySearchText.isEmpty {
                        Button(action: { historySearchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredHistory) { item in
                            HistoryThumbnail(item: item) {
                                if let index = ocrManager.recognitionHistory.firstIndex(where: { $0.id == item.id }) {
                                    ocrManager.recognitionHistory.remove(at: index)
                                }
                            }.onTapGesture { ocrManager.selectFromHistory(item) }
                        }
                        Button(action: { ocrManager.clearHistory() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                Text(settings.t(.ocrClearHistory))
                                    .font(.system(size: 8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.secondary)
                            .frame(width: 52, height: 52)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help(settings.t(.ocrClearHistory))
                    }.padding(4)
                }.frame(height: 60)
            }
        }
    }
    
    private var filteredHistory: [RecognitionResult] {
        if historySearchText.isEmpty {
            return ocrManager.recognitionHistory
        }
        return ocrManager.recognitionHistory.filter {
            $0.text.localizedCaseInsensitiveContains(historySearchText)
        }
    }

    // MARK: - Превью с рамками

    @ViewBuilder
    private var previewCard: some View {
        if let image = ocrManager.currentImage {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.opacity(0.05)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                    OCRBoxOverlay(imageSize: image.size,
                                  blocks: ocrManager.showTextBoxes ? ocrManager.textBlocks : [],
                                  barcodes: ocrManager.barcodes,
                                  onCopyBlock: { text in copyRaw(text) })
                        .padding(12)
                }
                .frame(height: 220)
                .clipped()

                Divider()

                HStack {
                    Label(settings.t(.previewLabel), systemImage: "photo")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)

                    Button {
                        ocrManager.showTextBoxes.toggle()
                    } label: {
                        Image(systemName: ocrManager.showTextBoxes ? "rectangle.dashed.badge.record" : "rectangle.dashed")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(ocrManager.showTextBoxes ? .blue : .secondary)
                    .help(settings.t(.ocrShowBoxes))

                    Spacer()

                    HStack(spacing: 0) {
                        Button(action: {
                            let pb = NSPasteboard.general; pb.clearContents(); pb.writeObjects([image])
                        }) {
                            Image(systemName: "doc.on.doc").font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 10).padding(.vertical, 6)
                        .help(settings.t(.btnCopyImage))

                        Divider().frame(height: 14)

                        Button(action: { saveImageToDisk(image: image) }) {
                            Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 10).padding(.vertical, 6)
                        .help(settings.t(.btnSaveImage))

                        Divider().frame(height: 16)

                        Button(action: { shareImageNative(image: image) }) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 10).padding(.vertical, 6)
                        .help(settings.t(.btnShare))
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))

                    Spacer()

                    Button(action: { withAnimation { ocrManager.clear() } }) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary).padding(6)
                            .background(Color.black.opacity(0.05)).clipShape(Circle())
                    }.buttonStyle(PlainButtonStyle()).help(settings.t(.previewClose))
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.3)), alignment: .top)
            }
            .background(DesignSystem.cardColor)
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius).stroke(DesignSystem.strokeColor, lineWidth: 1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Штрих-коды

    @ViewBuilder
    private var barcodesCard: some View {
        if !ocrManager.barcodes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "barcode.viewfinder").foregroundColor(.green)
                    Text(settings.t(.ocrBarcodes)).font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                ForEach(ocrManager.barcodes) { barcode in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(barcode.symbology)
                                .font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                            Text(barcode.value)
                                .font(.system(size: 11, design: .monospaced)).lineLimit(2)
                        }
                        Spacer()
                        Button { ocrManager.copyBarcode(barcode) } label: {
                            Image(systemName: "doc.on.doc").font(.system(size: 11))
                        }.buttonStyle(PlainButtonStyle())
                        if barcode.isURL, let url = URL(string: barcode.value) {
                            Button { NSWorkspace.shared.open(url) } label: {
                                Image(systemName: "arrow.up.right.square").font(.system(size: 11))
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            .padding(10)
            .background(DesignSystem.cardColor)
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius).stroke(Color.green.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Редактор текста

    private var textEditorCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(settings.t(.ocrResult)).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)

                if !ocrManager.recognizedText.isEmpty || ocrManager.detectedLanguage != nil {
                    languageBadge
                }

                if ocrManager.isTextEdited {
                    Label(settings.t(.ocrTextEdited), systemImage: "pencil")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Spacer()

                if !ocrManager.recognizedText.isEmpty {
                    Text("\(ocrManager.recognizedText.count) \(settings.t(.ocrCharsCount))")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)

                    SpeechControls(speech: speech, settings: settings, ocrManager: ocrManager, showTTS: $showTTS)

                    if ocrManager.isTextEdited {
                        Button(settings.t(.ocrResetText)) {
                            ocrManager.resetTextToOriginal()
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                    }

                    Menu {
                        ForEach(AIOperation.allCases) { op in
                            Button { ocrManager.processWithAI(operation: op) } label: { Label(op.title, systemImage: op.icon) }
                        }
                    } label: {
                        HStack(spacing: 4) { Image(systemName: "sparkles"); Text(settings.t(.ocrAI)) }
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(4)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .disabled(isBusy)
                }
            }
            .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)

            TextEditor(text: $ocrManager.recognizedText)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color.clear)
                .frame(minHeight: 140, maxHeight: .infinity)

            Divider()

            HStack(spacing: 12) {
                ActionButton(title: settings.t(.ocrCopy), icon: "text.alignleft") { ocrManager.copyText() }
                    .disabled(ocrManager.recognizedText.isEmpty)
                ActionButton(title: settings.t(.btnSave), icon: "doc.text") { ocrManager.saveToFile() }
                    .disabled(ocrManager.pages.isEmpty)
                if ocrManager.pages.count > 1 {
                    ActionButton(title: settings.t(.ocrCopyAllHint), icon: "rectangle.stack") { ocrManager.copyAllText() }
                }
                Spacer()
                Button { ocrManager.removeActivePage() } label: { Image(systemName: "trash").foregroundColor(.secondary) }
                    .buttonStyle(PlainButtonStyle()).help(settings.t(.ocrRemovePage))
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .background(DesignSystem.cardColor).cornerRadius(DesignSystem.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius).stroke(DesignSystem.strokeColor, lineWidth: 1))
    }

    // MARK: - Нижняя панель действий

    @ViewBuilder
    private var bottomBar: some View {
        if !ocrManager.pages.isEmpty {
            HStack(spacing: 10) {
                Menu {
                    Button {
                        ocrManager.reRecognizeActivePage()
                    } label: {
                        Label(settings.t(.ocrReRecognize), systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Menu {
                        ForEach(availableLanguages) { lang in
                            Button("\(lang.flag) \(lang.displayName)") {
                                ocrManager.reRecognizeActivePage(in: lang)
                            }
                        }
                    } label: {
                        Label(settings.t(.ocrRecognitionLanguage), systemImage: "character.book.closed")
                    }
                } label: {
                    Label(settings.t(.ocrReRecognize), systemImage: "arrow.clockwise")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .foregroundColor(.blue)
                .disabled(isBusy)

                Menu {
                    ForEach(OCRExportFormat.allCases) { format in
                        Button { ocrManager.export(as: format) } label: { Label(format.displayName, systemImage: format.icon) }
                    }
                } label: {
                    Label(settings.t(.ocrExport), systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(BorderlessButtonMenuStyle())

                Spacer()
                Button { ocrManager.clear() } label: {
                    Label(settings.t(.ocrClear), systemImage: "trash")
                }
                .buttonStyle(ModernButtonStyle(color: .red, variant: .ghost))
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor).opacity(0.3)), alignment: .top)
        }
    }

    private var dropHighlight: some View {
        Group {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Color.blue.opacity(0.06))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 26))
                            Text(settings.t(.ocrImportHint)).font(.system(size: 11, weight: .semibold))
                        }.foregroundColor(.blue)
                    )
                    .allowsHitTesting(false)
                    .padding(6)
            }
        }
    }

    // MARK: - Вспомогательное

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let lock = NSLock()
        var collected: [URL] = []
        var images: [NSImage] = []
        let group = DispatchGroup()
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    defer { group.leave() }
                    guard let data = data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    lock.lock(); collected.append(url); lock.unlock()
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                group.enter()
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    defer { group.leave() }
                    if let image = object as? NSImage {
                        lock.lock(); images.append(image); lock.unlock()
                    }
                }
            }
        }
        group.notify(queue: .main) {
            if !collected.isEmpty { ocrManager.importURLs(collected) }
            for image in images { ocrManager.importFromScanner(image) }
        }
        return true
    }

    private func copyRaw(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func saveImageToDisk(image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Scan_\(Int(Date().timeIntervalSince1970)).png"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url,
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }

    func shareImageNative(image: NSImage) {
        let picker = NSSharingServicePicker(items: [image])
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow, let contentView = window.contentView {
                picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
            }
        }
    }
}

// MARK: - Озвучка (контролы)

private struct SpeechControls: View {
    @ObservedObject var speech: SpeechService
    @ObservedObject var settings: SettingsManager
    @ObservedObject var ocrManager: OCRManager
    @Binding var showTTS: Bool

    var body: some View {
        HStack(spacing: 2) {
            Button {
                if speech.isSpeaking { ocrManager.stopSpeaking() } else { ocrManager.speakActivePage() }
            } label: {
                Image(systemName: speech.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(speech.isSpeaking ? .red : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(speech.isSpeaking ? settings.t(.ocrStopSpeak) : settings.t(.ocrSpeak))

            Button { showTTS = true } label: {
                Image(systemName: "slider.horizontal.2.square").font(.system(size: 11)).foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(settings.t(.ocrTTSSettings))
        }
    }
}

// MARK: - Рамки распознанного текста

struct OCRBoxOverlay: View {
    let imageSize: CGSize
    let blocks: [OCRTextBlock]
    let barcodes: [BarcodeResult]
    var onCopyBlock: (String) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let fitted = aspectFit(imageSize: imageSize, in: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(blocks) { block in
                    let rect = convert(block.rect, fitted: fitted)
                    Rectangle()
                        .stroke(Color.blue.opacity(0.75), lineWidth: 1)
                        .background(Color.blue.opacity(0.08))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .onTapGesture { onCopyBlock(block.text) }
                        .help(block.text)
                }
                ForEach(barcodes) { barcode in
                    let rect = convert(barcode.rect, fitted: fitted)
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(true)
    }

    private func aspectFit(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (container.width - width) / 2,
                      y: (container.height - height) / 2,
                      width: width, height: height)
    }

    private func convert(_ normalized: CGRect, fitted: CGRect) -> CGRect {
        CGRect(x: fitted.minX + normalized.minX * fitted.width,
               y: fitted.minY + (1 - normalized.maxY) * fitted.height,
               width: max(normalized.width * fitted.width, 2),
               height: max(normalized.height * fitted.height, 2))
    }
}

// MARK: - Миниатюры

struct PageThumbnail: View {
    let page: OCRPage
    let index: Int
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: page.image)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48).clipped()
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.black.opacity(0.6)).foregroundColor(.white)
                .cornerRadius(4).padding(2)
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.blue : Color.white.opacity(0.1), lineWidth: isActive ? 2 : 1))
    }
}

struct HistoryThumbnail: View {
    let item: RecognitionResult
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let image = item.previewImage {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: 48, height: 48).clipped()
                } else {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "text.alignleft").font(.caption).foregroundColor(.secondary)
                    }.frame(width: 48, height: 48)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHovered ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        .symbolRenderingMode(.palette).foregroundStyle(.white, .red).shadow(radius: 2)
                }.buttonStyle(PlainButtonStyle()).offset(x: 6, y: -6)
            }
        }
        .padding(4)
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { isHovered = h } }
    }
}

// MARK: - Кнопки

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12))
        }
        .buttonStyle(ActionButtonStyle())
        .help(title)
    }
}

struct ActionButtonStyle: ButtonStyle {
    var color: Color = .secondary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color == .secondary ? .primary : .white)
            .frame(width: 32, height: 32)
            .background(color == .secondary ? Color.black.opacity(0.05) : color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
