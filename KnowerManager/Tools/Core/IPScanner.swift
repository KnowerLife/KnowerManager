import Foundation
import Network
import Combine

// Модель результата
struct ScannedIP: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    let port: Int
    var latency: Double // мс
    var isWorking: Bool
}

class IPScanner: ObservableObject {
    static let shared = IPScanner()
    
    @Published var scannedIPs: [ScannedIP] = []
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var bestIP: String? = nil
    
    // Стандартные диапазоны Cloudflare
    private let cfRanges = [
        "162.159.192.0/24",
        "162.159.193.0/24",
        "162.159.195.0/24",
        "188.114.96.0/24",
        "188.114.97.0/24",
        "188.114.98.0/24",
        "188.114.99.0/24"
    ]
    
    func startScan() {
        // Защита от повторного запуска
        guard !isScanning else { return }
        
        // Сброс состояния
        DispatchQueue.main.async {
            self.isScanning = true
            self.scannedIPs.removeAll()
            self.progress = 0.0
            self.bestIP = nil
        }
        
        let totalChecks = 15
        var completedChecks = 0
        
        // Генерируем IP безопасно
        let targetIPs = generateRandomIPs(count: totalChecks)
        
        let group = DispatchGroup()
        let lock = NSLock() // Для синхронизации счетчика
        
        for ip in targetIPs {
            group.enter()
            // Безопасный выбор порта
            let port = [443, 2408].randomElement() ?? 2408
            
            checkLatency(ip: ip, port: port) { latency in
                DispatchQueue.main.async {
                    if let lat = latency {
                        let result = ScannedIP(ip: ip, port: port, latency: lat, isWorking: true)
                        self.scannedIPs.append(result)
                        // Сортировка: лучшие сверху
                        self.scannedIPs.sort { $0.latency < $1.latency }
                        
                        // Запоминаем лучший
                        if let first = self.scannedIPs.first {
                            self.bestIP = "\(first.ip):\(first.port)"
                        }
                    }
                    
                    // Обновляем прогресс бар
                    lock.lock()
                    completedChecks += 1
                    let prg = Double(completedChecks) / Double(totalChecks)
                    lock.unlock()
                    
                    self.progress = prg
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isScanning = false
            self.progress = 1.0
        }
    }
    
    // БЕЗОПАСНАЯ ПРОВЕРКА ЗАДЕРЖКИ
    private func checkLatency(ip: String, port: Int, completion: @escaping (Double?) -> Void) {
        let host = NWEndpoint.Host(ip)
        // Исправленная инициализация порта
        guard let portEndpoint = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(nil)
            return
        }
        
        let start = Date()
        let connection = NWConnection(host: host, port: portEndpoint, using: .tcp)
        
        // Флаг, чтобы не вызвать completion дважды (из-за чего был краш)
        var hasFinished = false
        let finishLock = NSLock()
        
        func finish(_ result: Double?) {
            finishLock.lock()
            defer { finishLock.unlock() }
            
            if !hasFinished {
                hasFinished = true
                connection.cancel()
                completion(result)
            }
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let time = Date().timeIntervalSince(start) * 1000
                finish(time)
            case .failed(_), .cancelled:
                finish(nil)
            default:
                break
            }
        }
        
        // Тайм-аут 1.5 секунды
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            // Если еще не готово, отменяем
            if connection.state != .ready {
                finish(nil)
            }
        }
        
        connection.start(queue: .global())
    }
    
    // БЕЗОПАСНАЯ ГЕНЕРАЦИЯ IP
    private func generateRandomIPs(count: Int) -> [String] {
        var results: [String] = []
        for _ in 0..<count {
            if let range = cfRanges.randomElement() {
                let parts = range.split(separator: "/")
                if let ipPart = parts.first {
                    let octets = ipPart.split(separator: ".")
                    if octets.count >= 3 {
                        let lastOctet = Int.random(in: 1...254)
                        let newIP = "\(octets[0]).\(octets[1]).\(octets[2]).\(lastOctet)"
                        results.append(newIP)
                    }
                }
            }
        }
        // Если что-то пошло не так, вернем хотя бы один дефолтный
        if results.isEmpty {
            return ["162.159.192.1", "188.114.97.1"]
        }
        return results
    }
}
