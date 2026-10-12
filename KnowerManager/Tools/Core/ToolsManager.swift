import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

// --- МОДЕЛЬ ЦЕЛИ МОНИТОРИНГА ---
struct PingTarget: Identifiable, Equatable, Codable {
    var id = UUID()
    var host: String
    var currentPing: Int = 0
    var history: [Double] = Array(repeating: 0.0, count: 20)
    var isChecking: Bool = false
    var status: ConnectionStatus = .idle
    
    enum ConnectionStatus: String, Codable {
        case idle, good, medium, bad, error
    }
}

class ToolsManager: ObservableObject {
    static let shared = ToolsManager()
    private let settings = SettingsManager.shared
    
    // --- Live Traffic Monitoring ---
    @Published var pingTargets: [PingTarget] = [] {
        didSet { saveTargets() }
    }
    private var monitorTimer: Timer?
    
    // --- Speed Test ---
    @Published var isTestingSpeed = false
    @Published var pingGoogle: Double = 0
    @Published var pingCloudflare: Double = 0
    @Published var downloadSpeed: String = "--"
    
    // --- Hostlist Management ---
    @Published var customDomains: [String] = [] {
        didSet {
            UserDefaults.standard.set(customDomains, forKey: "ToolsCustomDomains")
        }
    }
    
    // --- Diagnostics & Flush ---
    @Published var isCheckingConnection = false
    @Published var connectionStatus: Bool? = nil
    @Published var dnsFlushMessage: String = ""
    
    private init() {
        loadHostlist()
        loadTargets() // Загрузка целей мониторинга
        startMonitoring() // Запуск таймера
    }
    
    // MARK: - 1. Live Monitoring Logic
    
    func addTarget(_ host: String) {
        let clean = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Хост не должен быть пустым, дублироваться, содержать пробелы
        // или начинаться с "-" (иначе ping воспримет его как флаг).
        guard !clean.isEmpty,
              !clean.hasPrefix("-"),
              !clean.contains(where: { $0.isWhitespace }),
              !pingTargets.contains(where: { $0.host == clean }) else { return }
        
        let newTarget = PingTarget(host: clean)
        pingTargets.append(newTarget)
        refreshPing(for: newTarget.id)
    }
    
    func removeTarget(id: UUID) {
        if let index = pingTargets.firstIndex(where: { $0.id == id }) {
            pingTargets.remove(at: index)
        }
    }
    
    func clearAllTargets() {
        pingTargets.removeAll()
    }
    
    func startMonitoring() {
        stopMonitoring()
        // Интервал 15 секунд
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        refreshAll()
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    func refreshAll() {
        for target in pingTargets {
            refreshPing(for: target.id)
        }
    }
    
    private func refreshPing(for id: UUID) {
        guard let index = pingTargets.firstIndex(where: { $0.id == id }) else { return }
        let host = pingTargets[index].host
        
        // Индекс может устареть к моменту выполнения блока, поэтому ищем цель по id.
        DispatchQueue.main.async {
            if let idx = self.pingTargets.firstIndex(where: { $0.id == id }) {
                self.pingTargets[idx].isChecking = true
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            // Хост передаётся аргументом, а не подставляется в shell-строку —
            // это исключает инъекцию команд. Парсинг вывода делаем на Swift.
            let latency = self.pingHost(host)
            
            DispatchQueue.main.async {
                guard let idx = self.pingTargets.firstIndex(where: { $0.id == id }) else { return }
                self.pingTargets[idx].isChecking = false
                
                if let val = latency {
                    let pInt = Int(val)
                    self.pingTargets[idx].currentPing = pInt
                    
                    if self.pingTargets[idx].history.count >= 20 {
                        self.pingTargets[idx].history.removeFirst()
                    }
                    self.pingTargets[idx].history.append(val)
                    
                    if pInt < 100 { self.pingTargets[idx].status = .good }
                    else if pInt < 300 { self.pingTargets[idx].status = .medium }
                    else { self.pingTargets[idx].status = .bad }
                } else {
                    // Ошибка / Тайм-аут
                    self.pingTargets[idx].currentPing = 0
                    self.pingTargets[idx].status = .error
                    if self.pingTargets[idx].history.count >= 20 {
                        self.pingTargets[idx].history.removeFirst()
                    }
                    self.pingTargets[idx].history.append(0)
                }
            }
        }
    }
    
    /// Пингует хост и возвращает время отклика в миллисекундах либо nil.
    private func pingHost(_ host: String) -> Double? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "1", "-t", "1", host]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        
        do {
            try task.run()
        } catch {
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        guard let output = String(data: data, encoding: .utf8),
              let range = output.range(of: "time=") else { return nil }
        
        // Строка вида "time=12.345 ms" — берём числовой префикс после "time=".
        let value = output[range.upperBound...].prefix { $0.isNumber || $0 == "." }
        return Double(value)
    }
    
    private func saveTargets() {
        if let data = try? JSONEncoder().encode(pingTargets) {
            UserDefaults.standard.set(data, forKey: "ToolsPingTargets")
        }
    }
    
    private func loadTargets() {
        if let data = UserDefaults.standard.data(forKey: "ToolsPingTargets"),
           let saved = try? JSONDecoder().decode([PingTarget].self, from: data) {
            self.pingTargets = saved
        } else {
            // Дефолт
            self.pingTargets = [PingTarget(host: "1.1.1.1")]
        }
    }
    
    // MARK: - 2. Hostlist Presets
    func loadPreset(_ type: String) {
        let presets: [String: [String]] = [
            "socials": ["instagram.com", "facebook.com", "twitter.com", "linkedin.com"],
            "media": ["youtube.com", "discord.com", "netflix.com", "twitch.tv"],
            "news": ["bbc.com", "cnn.com"]
        ]
        
        guard let list = presets[type] else { return }
        
        for domain in list {
            if !customDomains.contains(where: { $0.lowercased() == domain }) {
                customDomains.append(domain)
            }
        }
    }
    
    func saveHostlist() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "list-general.txt"
        panel.title = settings.t(.hostSave)
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let listContent = self.customDomains.joined(separator: "\n")
                try? listContent.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func loadHostlist() {
        if let saved = UserDefaults.standard.stringArray(forKey: "ToolsCustomDomains") {
            customDomains = saved
        }
    }
    
    // MARK: - 3. Flush DNS
    func flushDNS() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-HUP", "mDNSResponder"]
        
        let task2 = Process()
        task2.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        task2.arguments = ["-flushcache"]
        
        DispatchQueue.global().async {
            try? process.run(); process.waitUntilExit()
            try? task2.run(); task2.waitUntilExit()
            
            DispatchQueue.main.async {
                self.dnsFlushMessage = self.settings.t(.flushDnsSuccess)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.dnsFlushMessage = ""
                }
            }
        }
    }
    
    // MARK: - 4. Diagnostics
    func checkConnection(url: String) {
        guard !url.isEmpty else { return }
        
        isCheckingConnection = true
        connectionStatus = nil
        
        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://" + urlString
        }
        
        guard let targetURL = URL(string: urlString) else {
            self.isCheckingConnection = false; self.connectionStatus = false; return
        }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                self.isCheckingConnection = false
                if let httpResponse = response as? HTTPURLResponse, (200...399).contains(httpResponse.statusCode) {
                    self.connectionStatus = true
                } else {
                    self.connectionStatus = false
                }
            }
        }.resume()
    }
    
    // MARK: - 5. Speed Test
    func runSpeedTest() {
        guard !isTestingSpeed else { return }
        isTestingSpeed = true
        pingGoogle = 0
        pingCloudflare = 0
        downloadSpeed = settings.t(.speedTesting)
        
        Task {
            let googleMs = await self.measureLatency(urlString: "https://www.google.com/generate_204")
            await MainActor.run { self.pingGoogle = googleMs ?? 0 }
            
            let cfMs = await self.measureLatency(urlString: "https://www.cloudflare.com/cdn-cgi/trace")
            await MainActor.run { self.pingCloudflare = cfMs ?? 0 }
            
            let speed = await self.measureDownloadSpeed()
            
            await MainActor.run {
                self.downloadSpeed = speed.map { String(format: "%.1f Mbps", $0) } ?? "--"
                self.isTestingSpeed = false
            }
        }
    }
    
    /// Измеряет время отклика (round-trip) до URL в миллисекундах.
    private func measureLatency(urlString: String) async -> Double? {
        guard let url = URL(string: urlString) else { return nil }
        let start = Date()
        do {
            _ = try await URLSession.shared.data(from: url)
            return Date().timeIntervalSince(start) * 1000
        } catch {
            return nil
        }
    }
    
    /// Реально измеряет скорость загрузки через эндпоинт Cloudflare.
    /// Возвращает Mbps либо nil при ошибке.
    private func measureDownloadSpeed() async -> Double? {
        let bytes = 10_000_000
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else { return nil }
        let start = Date()
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let elapsed = Date().timeIntervalSince(start)
            guard elapsed > 0, !data.isEmpty else { return nil }
            return Double(data.count) * 8 / elapsed / 1_000_000
        } catch {
            return nil
        }
    }
}
