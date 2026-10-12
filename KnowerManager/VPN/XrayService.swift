import Foundation
import Combine
import SwiftUI
import AppKit // Для NSPasteboard
import UniformTypeIdentifiers

class XrayService: ObservableObject {
    static let shared = XrayService()
    
    // --- PUBLISHED PROPERTIES (UI STATE) ---
    
    @Published var isRunning = false
    @Published var selectedProfileId: UUID?
    @Published var isPinging = false
    @Published var isImporting = false
    
    // --- УМНАЯ ПРОВЕРКА (DEEP SCAN) ---
        
    @Published var isDeepScanning = false
    @Published var scanProgress = (current: 0, total: 0)
    
    // Очередь сканирования
    private var deepScanQueue: [ShadowsocksProfile] = []
    
    func stopDeepScan() {
        isDeepScanning = false
        deepScanQueue.removeAll()
        scanProgress = (0, 0)
        // Намеренно НЕ вызываем stop(): воркеры сканирования работают на своих
        // портах и завершаются сами, а stop() оборвал бы активное VPN-соединение.
        print("🛑 Deep scan stopped.")
    }
        
    func startDeepScan(limit: Int? = nil) {
        // Оставляем фильтр latency != nil, так как проверка 17000 "мертвых по TCP" серверов займет вечность.
        let sorted = profiles
            .filter { $0.latency != nil }
            .sorted { $0.latency! < $1.latency! }
        
        let candidates: [ShadowsocksProfile]
        if let limit = limit {
            candidates = Array(sorted.prefix(limit))
        } else {
            candidates = sorted
        }
        
        guard !candidates.isEmpty else {
            print("⚠️ No candidates. Run Ping All first.")
            return
        }
        
        // Инициализация
        isDeepScanning = true
        deepScanQueue = candidates
        scanProgress = (current: 0, total: candidates.count)
        
        print("🧐 Starting TURBO Deep Scan for \(candidates.count) profiles...")
        
        // Запускаем многопоточную проверку
        runParallelScan()
    }
    
    // --- TURBO PARALLEL SCAN ---

    private func runParallelScan() {
        // 24 потока для максимальной скорости на macOS
        let threadCount = 24
        let basePort = 11000
        
        let dispatchGroup = DispatchGroup()
        let queueLock = NSLock()
        
        print("🚀 Starting TURBO Scan with \(threadCount) workers...")
        
        for i in 0..<threadCount {
            dispatchGroup.enter()
            let workerPort = basePort + i
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.runWorker(port: workerPort, queueLock: queueLock)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isDeepScanning = false
            // Не останавливаем основное соединение: воркеры сканирования уже
            // завершены, а активный VPN-профиль должен продолжать работать.
            self.saveProfiles()
            print("✅✅✅ Deep Scan FINISHED.")
        }
    }
    
    private func runWorker(port: Int, queueLock: NSLock) {
        let workerConfigPath = workDir.appendingPathComponent("config_\(port).json")
        
        while isDeepScanning {
            var profile: ShadowsocksProfile?
            
            // 1. Забираем задачу
            queueLock.lock()
            if !deepScanQueue.isEmpty {
                profile = deepScanQueue.removeFirst()
                // Обновляем UI пачками по 5, чтобы не фризить интерфейс
                if self.scanProgress.current % 5 == 0 {
                    DispatchQueue.main.async { self.scanProgress.current += 5 }
                }
            }
            queueLock.unlock()
            
            guard let currentProfile = profile else { break }
            
            // 2. Пишем конфиг
            let jsonConfig = XrayConfigGenerator.shared.createConfig(for: currentProfile, localPort: port)
            do {
                try jsonConfig.write(to: workerConfigPath, atomically: true, encoding: .utf8)
            } catch { continue }
            
            // 3. Запускаем Xray
            let task = Process()
            task.executableURL = binaryPath
            task.arguments = ["-config", workerConfigPath.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                
                // 4. Ждем порт (макс 3 сек)
                if waitForLocalPort(port: port, timeout: 3.0) {
                    
                    // 5. Проверка CURL (синхронно)
                    let (success, ms) = checkConnectivityCurlSync(port: port)
                    
                    // 6. Обновляем результат на главном потоке, находя профиль по id:
                    // индекс мог измениться, пока проверка выполнялась.
                    if success {
                        print("[\(port)] ⚡️ Alive: \(currentProfile.name) (\(Int(ms))ms)")
                        setLatency(Int(ms), for: currentProfile.id)
                    } else {
                        setLatency(-1, for: currentProfile.id)
                    }
                    
                } else {
                    // Xray не запустился
                    setLatency(-1, for: currentProfile.id)
                }
                
                task.terminate()
                
            } catch { }
            
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        try? FileManager.default.removeItem(at: workerConfigPath)
    }
    
    // Ожидание порта
    private func waitForLocalPort(port: Int, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            if fd >= 0 {
                var addr = sockaddr_in()
                addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(port).bigEndian
                addr.sin_addr.s_addr = inet_addr("127.0.0.1")
                
                let res = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                close(fd)
                if res == 0 { return true }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
    
    // Синхронная проверка CURL (для воркеров)
    private func checkConnectivityCurlSync(port: Int) -> (Bool, Double) {
        let start = Date()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        
        task.arguments = [
            "-x", "socks5h://127.0.0.1:\(port)",
            "-I", "-m", "3", "--connect-timeout", "2",
            "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "https://www.gstatic.com/generate_204"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let duration = Date().timeIntervalSince(start) * 1000
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if task.terminationStatus == 0 && output == "204" {
                return (true, duration)
            }
        } catch { }
        
        return (false, 0)
    }
    
    // --- ПЕРЕМЕННЫЕ И МЕТОДЫ (ОБЩИЕ) ---
    
    @Published var profiles: [ShadowsocksProfile] = [] {
        didSet {
            if !isPinging && !isImporting && !isDeepScanning {
                saveProfiles()
            }
        }
    }
    
    private var process: Process?
    private let localPort = 10808
    
    private var workDir: URL { FileManager.default.temporaryDirectory.appendingPathComponent("KnowerXray") }
    private var configPath: URL { workDir.appendingPathComponent("config.json") }
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KnowerManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("profiles.json")
    }
    
    private var binaryPath: URL {
        return Bundle.main.url(forResource: "xray-core", withExtension: nil) ?? URL(fileURLWithPath: "/usr/local/bin/xray")
    }

    private init() {
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        loadProfiles()
    }
    
    private func saveProfiles() {
        // Снимок делаем синхронно на вызывающем потоке (все вызовы идут с main),
        // а кодирование/запись — в фоне. Так мы не читаем @Published-массив
        // из фонового потока.
        let snapshot = profiles
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: self.storageURL)
            } catch { print("❌ Failed to save profiles: \(error)") }
        }
    }
    
    func addProfile(_ profile: ShadowsocksProfile) {
            DispatchQueue.main.async {
                self.profiles.append(profile)
                self.saveProfiles()
            }
        }
    
    // --- ОБНОВЛЕНИЕ ПРОФИЛЯ ---
        func updateProfile(_ updatedProfile: ShadowsocksProfile) {
            DispatchQueue.main.async {
                if let index = self.profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                    self.profiles[index] = updatedProfile
                    // Если мы редактируем текущий подключенный профиль - нужно перезапустить соединение
                    if self.isRunning && self.selectedProfileId == updatedProfile.id {
                        print("🔄 Profile updated while running. Restarting...")
                        self.start(profile: updatedProfile)
                    }
                    self.saveProfiles()
                }
            }
        }
    
    private func loadProfiles() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let loaded = try JSONDecoder().decode([ShadowsocksProfile].self, from: data)
            self.profiles = loaded
            print("📂 Loaded \(loaded.count) profiles from disk")
        } catch { print("❌ Failed to load profiles: \(error)") }
    }
    
    // --- РУЧНАЯ ПРОВЕРКА (КНОПКА "CHECK HTTP") ---
    // ОБНОВЛЕНО: ТЕПЕРЬ ИСПОЛЬЗУЕТ CURL (для надежности)
    func checkConnectivity(completion: @escaping (Bool, Double) -> Void) {
        performConnectivityCheck(attempt: 0, completion: completion)
    }
    
    private func performConnectivityCheck(attempt: Int, completion: @escaping (Bool, Double) -> Void) {
        // Для одиночной проверки используем CURL асинхронно, чтобы не блокировать UI
        // Это убирает ошибки -1200 и ATS Policy
        
        let start = Date()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        
        task.arguments = [
            "-x", "socks5h://127.0.0.1:\(localPort)",
            "-I", "-m", "5", // Таймаут 5 сек для ручной проверки
            "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "https://www.gstatic.com/generate_204"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                let duration = Date().timeIntervalSince(start) * 1000
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Если код выхода 0 и HTTP ответ 204
                if task.terminationStatus == 0 && output == "204" {
                    completion(true, duration)
                } else {
                    completion(false, 0)
                }
            } catch {
                completion(false, 0)
            }
        }
    }
    
    // --- УДАЛЕНИЕ ---
    func removeProfile(id: UUID) {
        DispatchQueue.main.async {
            if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                print("🗑 Auto-deleting dead profile: \(self.profiles[index].name)")
                self.profiles.remove(at: index)
                if self.selectedProfileId == id {
                    self.selectedProfileId = nil
                }
            }
        }
    }
    
    // --- МАССОВЫЙ ПИНГ (TCP) ---
    func pingAllProfiles(autoSelect: Bool = false) {
        guard !profiles.isEmpty else { return }
        isPinging = true
        print("🚀 Starting massive ping for \(profiles.count) profiles...")
        
        var idToIndexMap: [UUID: Int] = [:]
        for (index, profile) in profiles.enumerated() { idToIndexMap[profile.id] = index }
        
        let resultsQueue = DispatchQueue(label: "com.knower.pingResults", qos: .userInteractive)
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let semaphore = DispatchSemaphore(value: 60)
            let group = DispatchGroup()
            var pendingResults: [UUID: Int] = [:]
            var lastUiUpdateTime = Date()
            let profilesSnapshot = self.profiles
            
            for profile in profilesSnapshot {
                group.enter()
                semaphore.wait()
                TCPPing.ping(host: profile.server, port: profile.port) { ms in
                    defer { semaphore.signal(); group.leave() }
                    if let latency = ms {
                        resultsQueue.async {
                            pendingResults[profile.id] = latency
                            let now = Date()
                            if now.timeIntervalSince(lastUiUpdateTime) > 1.5 {
                                let batch = pendingResults
                                pendingResults.removeAll(keepingCapacity: true)
                                lastUiUpdateTime = now
                                DispatchQueue.main.async { self.applyBatchResults(batch, indexMap: idToIndexMap) }
                            }
                        }
                    }
                }
            }
            group.wait()
            resultsQueue.async {
                let finalBatch = pendingResults
                DispatchQueue.main.async {
                    self.applyBatchResults(finalBatch, indexMap: idToIndexMap)
                    self.isPinging = false
                    self.saveProfiles()
                    if autoSelect { self.selectBestProfile() }
                    print("✅ Massive ping finished.")
                }
            }
        }
    }
    
    // --- ПИНГ ВЫБРАННЫХ (TCP) ---
    func pingProfiles(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        isPinging = true
        print("🚀 Pinging \(ids.count) selected profiles...")
        
        var idToIndexMap: [UUID: Int] = [:]
        for (index, profile) in profiles.enumerated() { idToIndexMap[profile.id] = index }
        
        let profilesToPing = profiles.filter { ids.contains($0.id) }
        let resultsQueue = DispatchQueue(label: "com.knower.pingSelected", qos: .userInteractive)
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let group = DispatchGroup()
            let semaphore = DispatchSemaphore(value: 60)
            var pendingResults: [UUID: Int] = [:]
            
            for profile in profilesToPing {
                group.enter()
                semaphore.wait()
                TCPPing.ping(host: profile.server, port: profile.port) { ms in
                    defer { semaphore.signal(); group.leave() }
                    if let latency = ms {
                        resultsQueue.async { pendingResults[profile.id] = latency }
                    }
                }
            }
            group.wait()
            resultsQueue.async {
                let finalResults = pendingResults
                DispatchQueue.main.async {
                    self.applyBatchResults(finalResults, indexMap: idToIndexMap)
                    self.isPinging = false
                    self.saveProfiles()
                    print("✅ Selected ping finished.")
                }
            }
        }
    }
    
    private func applyBatchResults(_ results: [UUID: Int], indexMap: [UUID: Int]) {
        for (id, latency) in results {
            if let index = indexMap[id], index < self.profiles.count, self.profiles[index].id == id {
                self.profiles[index].latency = latency
            }
        }
    }
    
    /// Безопасно обновляет задержку профиля на главном потоке, находя его по id.
    private func setLatency(_ value: Int, for id: UUID) {
        DispatchQueue.main.async {
            if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                self.profiles[index].latency = value
            }
        }
    }
    
    // --- ИМПОРТ ---
    func importFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) { parseAndAdd(text: str) }
    }
    func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .plainText]
        if panel.runModal() == .OK, let url = panel.url, let text = try? String(contentsOf: url) {
            parseAndAdd(text: text)
        }
    }
    func importFromURL(_ urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let text = String(data: data, encoding: .utf8) { self?.parseAndAdd(text: text) }
        }
        task.resume()
    }
    
    private func parseAndAdd(text: String) {
        DispatchQueue.main.async { self.isImporting = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var cleanText = text.replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: " ", with: "\n")
            if !cleanText.contains("://"), let data = Data(base64Encoded: cleanText.trimmingCharacters(in: .whitespacesAndNewlines)), let decoded = String(data: data, encoding: .utf8) { cleanText = decoded }
            
            let lines = cleanText.components(separatedBy: .newlines)
            var newProfiles: [ShadowsocksProfile] = []
            for line in lines {
                let trim = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trim.isEmpty { continue }
                if trim.hasPrefix("ss://") { if let p = SSParser.shared.parse(link: trim) { newProfiles.append(p) } }
                else if trim.hasPrefix("vmess://") { if let p = VMessParser.shared.parse(link: trim) { newProfiles.append(p) } }
                else if trim.hasPrefix("vless://") || trim.hasPrefix("trojan://") { if let p = VLESSParser.shared.parse(link: trim) { newProfiles.append(p) } }
            }
            
            let existingKeys = Set(self.profiles.map { "\($0.server):\($0.port)" })
            let uniqueProfiles = newProfiles.filter { !existingKeys.contains("\($0.server):\($0.port)") }
            
            DispatchQueue.main.async {
                if !uniqueProfiles.isEmpty { self.profiles.append(contentsOf: uniqueProfiles) }
                self.isImporting = false
                self.saveProfiles()
                print("✅ Imported \(uniqueProfiles.count) profiles")
            }
        }
    }
    
    // --- УПРАВЛЕНИЕ СПИСКОМ ---
    func toggleFavorite(id: UUID) {
        if let index = profiles.firstIndex(where: { $0.id == id }) { profiles[index].isBookmarked.toggle() }
    }
    
    func removeDeadProfiles() {
        DispatchQueue.main.async {
            self.profiles.removeAll { $0.latency == nil || ($0.latency ?? 0) < 0 }
            if let id = self.selectedProfileId, !self.profiles.contains(where: { $0.id == id }) { self.selectedProfileId = nil }
            self.saveProfiles()
        }
    }
    
    func selectBestProfile() {
        if let best = profiles.filter({ $0.latency != nil }).min(by: { $0.latency! < $1.latency! }) {
            self.selectedProfileId = best.id
        }
    }
    
    // --- ПОДКЛЮЧЕНИЕ ---
    func toggleConnection() {
        if isRunning { stop() }
        else if let id = selectedProfileId, let profile = profiles.first(where: { $0.id == id }) { start(profile: profile) }
    }
    
    func start(profile: ShadowsocksProfile) {
        stop()
        let jsonConfig = XrayConfigGenerator.shared.createConfig(for: profile, localPort: localPort)
        try? jsonConfig.write(to: configPath, atomically: true, encoding: .utf8)
        
        let task = Process()
        task.executableURL = binaryPath
        task.arguments = ["-config", configPath.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let startTime = Date()
        
        do {
            try task.run()
            self.process = task
            task.terminationHandler = { [weak self] _ in
                guard let self = self else { return }
                let duration = Date().timeIntervalSince(startTime)
                DispatchQueue.main.async {
                    if self.isRunning && duration < 1.5 {
                        print("💀 Instant crash. Removing profile...")
                        self.removeProfile(id: profile.id)
                    }
                    self.isRunning = false
                    self.setSystemProxy(enabled: false)
                }
            }
            DispatchQueue.main.async { self.isRunning = true }
            print("✅ Xray started on \(localPort)")
            setSystemProxy(enabled: true)
        } catch { print("❌ Start failed: \(error)") }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        DispatchQueue.main.async { self.isRunning = false }
        setSystemProxy(enabled: false)
    }
    
    private func setSystemProxy(enabled: Bool) {
        if enabled && KnowerManager.shared.isRunning { DispatchQueue.main.async { KnowerManager.shared.stopKnower() } }
        let script = enabled ?
            "networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do if networksetup -getinfo \"$s\" | grep -q \"IP address\"; then networksetup -setsocksfirewallproxy \"$s\" 127.0.0.1 \(localPort); networksetup -setsocksfirewallproxystate \"$s\" on; fi; done" :
            "networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do networksetup -setsocksfirewallproxystate \"$s\" off; done"
        
        KnowerManager.shared.runAsAdmin(script: script) { _, _ in }
    }
}
