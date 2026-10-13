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
    /// UUID профиля, который реально стартовал (для трея/настроек). nil — нет соединения.
    @Published var activeProfileId: UUID?
    /// Последняя ошибка запуска/соединения (для показа в UI). nil — ошибок нет.
    @Published var lastError: String?
    
    // --- УМНАЯ ПРОВЕРКА (DEEP SCAN) ---
        
    @Published var isDeepScanning = false
    @Published var scanProgress = ScanProgress(current: 0, total: 0)
    
    // Очередь сканирования
    private var deepScanQueue: [ShadowsocksProfile] = []
    
    struct ScanProgress: Equatable {
        var current: Int
        var total: Int
    }
    
    func stopDeepScan() {
        isDeepScanning = false
        deepScanQueue.removeAll()
        scanProgress = ScanProgress(current: 0, total: 0)
        // Намеренно НЕ вызываем stop(): воркеры сканирования работают на своих
        // портах и завершаются сами, а stop() оборвал бы активное VPN-соединение.
        AppLogger.shared.info("🛑 Deep scan stopped.")
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
            AppLogger.shared.warning("No candidates. Run Ping All first.")
            return
        }
        
        // Инициализация
        isDeepScanning = true
        deepScanQueue = candidates
        scanProgress = ScanProgress(current: 0, total: candidates.count)
        
        AppLogger.shared.info("🧐 Starting TURBO Deep Scan for \(candidates.count) profiles...")
        
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
        
        AppLogger.shared.info("🚀 Starting TURBO Scan with \(threadCount) workers...")
        
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
            AppLogger.shared.info("✅✅✅ Deep Scan FINISHED.")
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
                        AppLogger.shared.info("[\(port)] ⚡️ Alive: \(currentProfile.name) (\(Int(ms))ms)")
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
    /// Момент установки соединения (для «тихих» уведомлений при быстрых переключениях).
    private var connectedAt: Date?
    
    // --- ЛОГ XRAY ---
    @Published var xrayLog: String = ""
    private let logMaxLines = 400
    private var logLines: [String] = []
    
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
            } catch { AppLogger.shared.error("Failed to save profiles: \(error)") }
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
                        AppLogger.shared.info("🔄 Profile updated while running. Restarting...")
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
            AppLogger.shared.info("📂 Loaded \(loaded.count) profiles from disk")
        } catch { AppLogger.shared.error("Failed to load profiles: \(error)") }
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
                self.profiles.remove(at: index)
                if self.selectedProfileId == id {
                    self.selectedProfileId = nil
                }
                // Если удаляем профиль, через который сейчас установлено
                // соединение — гасим его, чтобы Xray не остался с чужим конфигом.
                if self.activeProfileId == id { self.stop() }
            }
        }
    }
    
    // --- МАССОВЫЙ ПИНГ (TCP) ---
    func pingAllProfiles(autoSelect: Bool = false) {
        guard !profiles.isEmpty else { return }
        isPinging = true
        AppLogger.shared.info("🚀 Starting massive ping for \(profiles.count) profiles...")
        
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
                    AppLogger.shared.info("✅ Massive ping finished.")
                }
            }
        }
    }
    
    // --- ПИНГ ВЫБРАННЫХ (TCP) ---
    func pingProfiles(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        isPinging = true
        AppLogger.shared.info("🚀 Pinging \(ids.count) selected profiles...")
        
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
                    AppLogger.shared.info("✅ Selected ping finished.")
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
        // Ссылка превращается в подписку с автообновлением.
        SubscriptionManager.shared.addSubscription(url: urlString)
    }

    /// Импорт QR-кода из буфера обмена (изображение).
    func importFromQRClipboard() {
        guard let image = QRCodeService.imageFromPasteboard() else {
            DispatchQueue.main.async { self.isImporting = false }
            return
        }
        importQRFromImage(image)
    }

    /// Импорт QR-кода из файла изображения.
    func importFromQRImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url,
                  let image = NSImage(contentsOf: url) else { return }
            self?.importQRFromImage(image)
        }
    }

    /// Декодирует QR на изображении и импортирует найденные ссылки.
    func importQRFromImage(_ image: NSImage) {
        DispatchQueue.main.async { self.isImporting = true }
        Task {
            let payloads = await QRCodeService.decode(in: image)
            let text = payloads.joined(separator: "\n")
            if text.isEmpty {
                DispatchQueue.main.async { self.isImporting = false }
                return
            }
            parseAndAdd(text: text)
        }
    }
    
    private func parseAndAdd(text: String) {
        DispatchQueue.main.async { self.isImporting = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let newProfiles = LinkParser.parseLinks(from: text)
            let existingKeys = Set(self.profiles.map { "\($0.server):\($0.port)" })
            let uniqueProfiles = newProfiles.filter { !existingKeys.contains("\($0.server):\($0.port)") }
            
            DispatchQueue.main.async {
                if !uniqueProfiles.isEmpty { self.profiles.append(contentsOf: uniqueProfiles) }
                self.isImporting = false
                self.saveProfiles()
                AppLogger.shared.info("✅ Imported \(uniqueProfiles.count) profiles")
            }
        }
    }
    
    // --- УПРАВЛЕНИЕ СПИСКОМ ---
    func toggleFavorite(id: UUID) {
        if let index = profiles.firstIndex(where: { $0.id == id }) { profiles[index].isBookmarked.toggle() }
    }
    
    // --- ПОДПИСКИ ---

    /// Заменяет профили подписки новыми. Для существующих серверов
    /// сохраняет стабильный id, пинг и «избранное».
    func applySubscriptionProfiles(_ newProfiles: [ShadowsocksProfile], subscriptionId: UUID) {
        DispatchQueue.main.async { [self] in
            let oldProfiles = self.profiles.filter { $0.subscriptionId == subscriptionId }
            var oldIndex: [String: ShadowsocksProfile] = [:]
            for p in oldProfiles {
                oldIndex["\(p.server.lowercased()):\(p.port):\(p.protocolType.rawValue)"] = p
            }
            let manual = self.profiles.filter { $0.subscriptionId == nil }

            var updated: [ShadowsocksProfile] = []
            for var p in newProfiles {
                let key = "\(p.server.lowercased()):\(p.port):\(p.protocolType.rawValue)"
                if let old = oldIndex[key] {
                    // Сохраняем стабильный id + накопленные метаданные.
                    p.id = old.id
                    p.isFavorite = old.isFavorite
                    p.latency = old.latency
                } else {
                    p.id = UUID()
                    p.latency = nil
                }
                p.subscriptionId = subscriptionId
                updated.append(p)
            }

            // Единое присваивание — один didSet и одна запись на диск.
            self.profiles = manual + updated
            if let sel = self.selectedProfileId, !self.profiles.contains(where: { $0.id == sel }) {
                self.selectedProfileId = nil
            }
            AppLogger.shared.info("✅ Subscription \(subscriptionId) update applied: \(updated.count) profiles")
        }
    }

    /// Удаляет все профили подписки (при удалении самой подписки).
    func removeProfiles(subscriptionId: UUID) {
        DispatchQueue.main.async { [self] in
            let selectedWasRemoved = self.selectedProfileId.flatMap { sel in
                self.profiles.first(where: { $0.id == sel })?.subscriptionId == subscriptionId
            } ?? false
            self.profiles.removeAll { $0.subscriptionId == subscriptionId }
            if selectedWasRemoved {
                self.selectedProfileId = nil
                if self.isRunning { self.stop() }
            }
            AppLogger.shared.info("🗑 Removed profiles of subscription \(subscriptionId)")
        }
    }
    
    func removeDeadProfiles() {
        DispatchQueue.main.async {
            // Удаляем ТОЛЬКО подтверждённо мёртвые (latency < 0).
            // Профили без пинга (latency == nil) не трогаем.
            self.profiles.removeAll { ($0.latency ?? 0) < 0 }
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
        lastError = nil
        let jsonConfig = XrayConfigGenerator.shared.createConfig(for: profile, localPort: localPort)
        try? jsonConfig.write(to: configPath, atomically: true, encoding: .utf8)
        
        let task = Process()
        task.executableURL = binaryPath
        task.arguments = ["-config", configPath.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let startTime = Date()
        clearLog()
        
        do {
            try task.run()
            self.process = task
            // Читаем stdout/stderr в фоне: буфер канала (64КБ) без чтения
            // заблокировал бы Xray при обильном логировании.
            let fh = pipe.fileHandleForReading
            Thread.detachNewThread { [weak self] in
                while true {
                    let data = fh.availableData
                    if data.isEmpty { break } // EOF
                    guard let text = String(data: data, encoding: .utf8) else { continue }
                    self?.appendXrayLog(text)
                }
            }
            task.terminationHandler = { [weak self] proc in
                guard let self = self else { return }
                let duration = Date().timeIntervalSince(startTime)
                DispatchQueue.main.async {
                    // Если процесс уже не текущий (переключение профиля/остановка),
                    // не трогаем состояние нового соединения.
                    guard self.process === proc else { return }
                    self.process = nil
                    if self.isRunning && duration < 1.5 {
                        // Больше НЕ удаляем профиль автоматически: это мог быть
                        // сбой сети/сервера, а не проблема конфига. Показываем ошибку.
                        let message = SettingsManager.shared.t(.vpnInstantCrash)
                        self.lastError = message
                        self.appendXrayLog(message)
                        SettingsManager.shared.sendNotification(
                            title: SettingsManager.shared.t(.vpnTitle),
                            body: message)
                    }
                    self.connectedAt = nil
                    self.activeProfileId = nil
                    self.isRunning = false
                    self.setSystemProxy(enabled: false)
                }
            }
            DispatchQueue.main.async {
                self.activeProfileId = profile.id
                self.connectedAt = Date()
                self.isRunning = true
                SettingsManager.shared.sendNotification(
                    title: SettingsManager.shared.t(.vpnTitle),
                    body: SettingsManager.shared.t(.vpnNotifyConnected))
            }
            AppLogger.shared.info("✅ Xray started on \(localPort)")
            setSystemProxy(enabled: true)
        } catch { AppLogger.shared.error("Start failed: \(error)") }
    }
    
    // MARK: - Лог Xray (кольцевой буфер последних строк)
    
    private func clearLog() {
        DispatchQueue.main.async {
            self.logLines.removeAll()
            self.xrayLog = ""
        }
    }
    
    private func appendXrayLog(_ chunk: String) {
        DispatchQueue.main.async {
            for line in chunk.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { self.logLines.append(trimmed) }
            }
            if self.logLines.count > self.logMaxLines {
                self.logLines.removeFirst(self.logLines.count - self.logMaxLines)
            }
            self.xrayLog = self.logLines.joined(separator: "\n")
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.activeProfileId = nil
            // Уведомляем об отключении, только если соединение жило достаточно долго
            // (иначе при переключении профилей получится двойное уведомление).
            if let start = self.connectedAt, Date().timeIntervalSince(start) > 2 {
                SettingsManager.shared.sendNotification(
                    title: SettingsManager.shared.t(.vpnTitle),
                    body: SettingsManager.shared.t(.vpnNotifyDisconnected))
            }
            self.connectedAt = nil
        }
        setSystemProxy(enabled: false)
    }
    
    /// Открывает в Finder папку с данными приложения (профили, подписки, история).
    func openDataFolder() {
        let folder = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
    
    private func setSystemProxy(enabled: Bool) {
        let script = enabled ?
            "networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do if networksetup -getinfo \"$s\" | grep -q \"IP address\"; then networksetup -setsocksfirewallproxy \"$s\" 127.0.0.1 \(localPort); networksetup -setsocksfirewallproxystate \"$s\" on; fi; done" :
            "networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do networksetup -setsocksfirewallproxystate \"$s\" off; done"
        
        PrivilegedRunner.shared.runAsAdmin(script: script) { _, _ in }
    }
}
