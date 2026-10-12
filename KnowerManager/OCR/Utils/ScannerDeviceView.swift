import SwiftUI
import Quartz
import ImageCaptureCore

/// Обёртка над IKScannerDeviceView (ImageKit) — системный UI для работы
/// с подключённым сканером. Сканирует в память и отдаёт NSImage.
struct ScannerDeviceView: NSViewRepresentable {
    /// Вызывается для каждой отсканированной страницы.
    var onScan: (NSImage) -> Void
    /// Вызывается при ошибке сканера.
    var onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }

    func makeNSView(context: Context) -> IKScannerDeviceView {
        let view = IKScannerDeviceView()
        view.delegate = context.coordinator
        view.transferMode = .memoryBased
        view.hasDisplayModeSimple = true
        view.hasDisplayModeAdvanced = true
        view.mode = .advanced
        view.displaysDownloadsDirectoryControl = false
        view.displaysPostProcessApplicationControl = false
        view.scanControlLabel = SettingsManager.shared.t(.ocrScannerScan)
        view.overviewControlLabel = SettingsManager.shared.t(.ocrScannerOverview)
        return view
    }

    func updateNSView(_ nsView: IKScannerDeviceView, context: Context) {}

    final class Coordinator: NSObject, IKScannerDeviceViewDelegate {
        let onScan: (NSImage) -> Void
        let onError: (Error) -> Void

        init(onScan: @escaping (NSImage) -> Void, onError: @escaping (Error) -> Void) {
            self.onScan = onScan
            self.onError = onError
        }

        func scannerDeviceView(_ scannerDeviceView: IKScannerDeviceView,
                               didScanTo url: URL,
                               fileData: Data,
                               error: Error?) {
            if let error = error {
                onError(error)
                return
            }
            if let image = NSImage(data: fileData) {
                onScan(image)
            }
        }

        func scannerDeviceView(_ scannerDeviceView: IKScannerDeviceView,
                               didScanTo url: URL,
                               error: Error?) {
            if let error = error {
                onError(error)
                return
            }
            if let image = NSImage(contentsOf: url) {
                onScan(image)
            }
        }

        func scannerDeviceView(_ scannerDeviceView: IKScannerDeviceView,
                               didEncounterError error: Error) {
            onError(error)
        }
    }
}
