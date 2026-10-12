import Foundation
import Combine
import Network
import UserNotifications

// Автономная структура стратегии для KnowerWatch
struct KnowerWatchStrategy {
    let name: String
    let args: String
}

class KnowerWatchService: ObservableObject {
    // Переименовали синглтон
    static let shared = KnowerWatchService()
    
    // --- НАСТРОЙКИ ---
    private static let enabledKey = "knowerWatchEnabled"
    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: KnowerWatchService.enabledKey) {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled { startMonitoring() } else { stopMonitoring() }
        }
    }
    
    private let checkInterval: TimeInterval = 300 // 5 минут
    private let failureThreshold = 3
    
    // --- СОСТОЯНИЕ ---
    private var failureCount = 0
    private var timer: Timer?
    private var isHealing = false
    
    // Порт отличается от порта авто-проверки KnowerManager (12988), иначе
    // одновременные пробы конфликтуют и дают ложные сбои.
    private let testPort = "12989"
    private var workingDir: URL { return URL(fileURLWithPath: "/tmp/KnowerManager", isDirectory: true) }
    private var tpwsPath: URL { return workingDir.appendingPathComponent("tpws") }
    
    // Список стратегий для "Магического лечения"
    private let healingStrategies: [KnowerWatchStrategy] = [
        KnowerWatchStrategy(name: "Disorder Standard", args: "--disorder --split-pos=2 --hostcase"),
        KnowerWatchStrategy(name: "Clash Mode", args: "--disorder --split-pos=2 --mss=1100 --split-any-protocol --hostcase"),
        KnowerWatchStrategy(name: "Split 2 Safe", args: "--split-pos=2 --hostcase --mss=1200"),
        KnowerWatchStrategy(name: "OOB Simple", args: "--oob --split-pos=2 --hostcase"),
        KnowerWatchStrategy(name: "BadSeq Fix", args: "--disorder --split-pos=2 --badseq --hostcase"),
        KnowerWatchStrategy(name: "TLS Record Split", args: "--tlsrec=sni+2 --split-pos=2 --hostcase"),
        KnowerWatchStrategy(name: "Fake (OOB+Disorder)", args: "--disorder --split-pos=2 --oob --hostcase")
    ]
    
    private let targets = [
        "https://www.youtube.com",
        "https://www.instagram.com",
        "https://www.google.com"
    ]
    
    private init() {
        // Если функция была включена в прошлом запуске — восстанавливаем мониторинг.
        if isEnabled {
            DispatchQueue.main.async { [weak self] in self?.startMonitoring() }
        }
    }
    
    // MARK: - MONITORING
    
    func startMonitoring() {
        stopMonitoring()
        guard isEnabled else { return }
        
        print("👁️ KnowerWatch: Запущен мониторинг (интервал \(Int(checkInterval))с)")
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        failureCount = 0
        print("👁️ KnowerWatch: Остановлен")
    }
    
    private func performHealthCheck() {
        guard !isHealing, KnowerManager.shared.isRunning else { return }
        
        print("👁️ KnowerWatch: Проверка соединения...")
        checkConnectivity { success in
            if success {
                print("👁️ KnowerWatch: Связь в порядке")
                self.failureCount = 0
            } else {
                self.failureCount += 1
                print("👁️ KnowerWatch: ⚠️ Ошибка связи (\(self.failureCount)/\(self.failureThreshold))")
                
                if self.failureCount >= self.failureThreshold {
                    self.triggerMagicHeal()
                }
            }
        }
    }
    
    private func checkConnectivity(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let url = self.targets[0]
            // Используем curl для проверки
            let res = self.runShell("curl -I -k -s -o /dev/null -w \"%{http_code}\" -m 5 \(url)").trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                if ["200", "301", "302"].contains(res) {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - MAGIC HEAL
    
    private func triggerMagicHeal() {
        isHealing = true
        stopMonitoring()
        
        print("👁️ KnowerWatch: 🚑 НАЧИНАЮ ВОССТАНОВЛЕНИЕ...")
        
        DispatchQueue.main.async {
            KnowerManager.shared.stopKnower()
            // 1. ЛОКАЛИЗАЦИЯ СТАТУСА (Поиск решения...)
            KnowerManager.shared.statusMessage = SettingsManager.shared.t(.kwSearchingStatus)
        }
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) {
            
            var bestStrategy: KnowerWatchStrategy? = nil
            var maxScore = -1
            
            for strategy in self.healingStrategies {
                print("👁️ KnowerWatch Test: \(strategy.name)")
                
                let pid = self.runShell("'\(self.tpwsPath.path)' --port=\(self.testPort) --socks --bind-addr=127.0.0.1 \(strategy.args) > /dev/null 2>&1 & echo $!").trimmingCharacters(in: .whitespacesAndNewlines)
                Thread.sleep(forTimeInterval: 0.5)
                
                var score = 0
                for url in self.targets {
                    let res = self.runShell("curl -k -s -o /dev/null -w \"%{http_code}\" --socks5 127.0.0.1:\(self.testPort) -m 2 \(url)").trimmingCharacters(in: .whitespacesAndNewlines)
                    if ["200","301","302"].contains(res) { score += 1 }
                }
                
                _ = self.runShell("kill -9 \(pid)")
                
                if score > maxScore {
                    maxScore = score
                    bestStrategy = strategy
                }
                
                if score == self.targets.count { break }
            }
            
            DispatchQueue.main.async {
                if let winner = bestStrategy, maxScore > 0 {
                    print("👁️ KnowerWatch: 🏆 Найдено решение: \(winner.name)")
                    
                    KnowerManager.shared.foundBestArgs = winner.args
                    KnowerManager.shared.selectedStrategy = .auto
                    KnowerManager.shared.startKnower()
                    
                    // 2. ЛОКАЛИЗАЦИЯ УВЕДОМЛЕНИЯ (Интернет восстановлен: ...)
                    self.sendNotification(body: "\(SettingsManager.shared.t(.kwRestoredBody)) \(winner.name)")
                } else {
                    print("👁️ KnowerWatch: 💀 Решение не найдено. Перезапуск текущей.")
                    KnowerManager.shared.startKnower()
                }
                
                self.failureCount = 0
                self.isHealing = false
                self.startMonitoring()
            }
        }
    }
    
    private func runShell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        task.standardOutput = pipe
        task.standardInput = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            print("runShell failed: \(error)")
            return ""
        }
        // Читаем до waitUntilExit, чтобы избежать взаимоблокировки на большом выводе.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func sendNotification(body: String) {
            // Уважаем общий переключатель уведомлений и не трогаем
            // UNUserNotificationCenter без настоящего bundle identifier.
            guard SettingsManager.shared.showNotifications, Bundle.main.bundleIdentifier != nil else { return }
            // Создаем контент уведомления (современный API)
            let content = UNMutableNotificationContent()
            
            // 3. ЛОКАЛИЗАЦИЯ ЗАГОЛОВКА (KnowerWatch)
            content.title = SettingsManager.shared.t(.kwNotificationTitle)
            content.body = body
            content.sound = .default

            // Создаем запрос с уникальным ID (триггер nil означает "отправить немедленно")
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

            // Отправляем через современный центр уведомлений
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Ошибка отправки уведомления KnowerWatch: \(error.localizedDescription)")
                }
            }
        }
}
