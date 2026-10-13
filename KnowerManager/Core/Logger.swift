import Foundation
import Combine

// MARK: - Централизованный логгер
//
// Заменяет print() с уровнями (debug/info/warning/error), ротацией файлов
// и опциональным показом в UI.

enum LogLevel: Int, CaseIterable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    /// Минимальный уровень для записи в файл.
    var minimumLevel: LogLevel = .debug

    /// Показывать ли логи в UI (для отладки).
    @Published var isUILogVisible = false

    /// Последние N строк лога для отображения в UI.
    @Published var uiLogLines: [String] = []
    private let maxUILines = 200

    private var logFileURL: URL?
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private let maxArchivedFiles = 3
    private let queue = DispatchQueue(label: "com.knower.logger", qos: .utility)

    private init() {
        setupLogFile()
    }

    // MARK: - Public API

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    /// Возвращает путь к текущему лог-файлу.
    var currentLogPath: URL? { logFileURL }

    /// Очищает текущий лог-файл.
    func clearLogFile() {
        guard let url = logFileURL else { return }
        queue.async {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Private

    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }

        let timestamp = Self.dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let line = "\(timestamp) \(level.emoji) [\(level.label)] \(fileName):\(line) \(function) — \(message)"

        // Консоль
        print(line)

        // UI
        DispatchQueue.main.async { [weak self] in
            self?.uiLogLines.append(line)
            if let count = self?.uiLogLines.count, count > (self?.maxUILines ?? 200) {
                self?.uiLogLines.removeFirst(count - (self?.maxUILines ?? 200))
            }
        }

        // Файл
        queue.async { [weak self] in
            self?.writeToFile(line)
        }
    }

    private func writeToFile(_ line: String) {
        guard let url = logFileURL else { return }

        // Проверяем размер и ротируем если нужно
        rotateIfNeeded(url)

        let lineWithNewline = line + "\n"
        if let data = lineWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }

    private func rotateIfNeeded(_ url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? UInt64,
              size > maxFileSize else { return }

        // Удаляем самый старый архив
        let oldestArchive = url.appendingPathExtension(".\(maxArchivedFiles).log")
        try? FileManager.default.removeItem(at: oldestArchive)

        // Сдвигаем архивы
        for i in (1..<maxArchivedFiles).reversed() {
            let from = url.appendingPathExtension(".\(i).log")
            let to = url.appendingPathExtension(".\(i + 1).log")
            try? FileManager.default.moveItem(at: from, to: to)
        }

        // Текущий файл -> .1.log
        let firstArchive = url.appendingPathExtension(".1.log")
        try? FileManager.default.moveItem(at: url, to: firstArchive)
    }

    private func setupLogFile() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("KnowerManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logFileURL = dir.appendingPathComponent("app.log")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
