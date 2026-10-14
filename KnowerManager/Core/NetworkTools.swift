import Foundation

// MARK: - Сетевые инструменты (DNS Flush, Монитор трафика, Диагностика)

enum NetworkTools {

    // MARK: DNS Flush

    // Все методы помечены `nonisolated`, чтобы блокирующие системные вызовы
    // (Process.waitUntilExit) не выполнялись на главном потоке и не «морозили» UI.

    /// Сбрасывает кэш DNS macOS.
    nonisolated static func flushDNS() async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        task.arguments = ["-flushcache"]

        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killTask.arguments = ["-HUP", "mDNSResponder"]

        do {
            try task.run()
            task.waitUntilExit()
            try killTask.run()
            killTask.waitUntilExit()
        } catch {
            throw error
        }
    }

    // MARK: Монитор трафика

    /// Считает трафик через getifaddrs (без сторонних зависимостей).
    struct TrafficStats: Sendable {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let packetsIn: UInt64
        let packetsOut: UInt64

        var total: UInt64 { bytesIn + bytesOut }
    }

    nonisolated static func getTrafficStats() -> TrafficStats {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var packetsIn: UInt64 = 0
        var packetsOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return TrafficStats(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr

            // Только активные интерфейсы (UP, RUNNING), исключаем loopback
            if (flags & IFF_UP) == IFF_UP && (flags & IFF_LOOPBACK) == 0,
               let addr = addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = ptr.pointee.ifa_data
                if let data = data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    bytesIn += UInt64(stats.ifi_ibytes)
                    bytesOut += UInt64(stats.ifi_obytes)
                    packetsIn += UInt64(stats.ifi_ipackets)
                    packetsOut += UInt64(stats.ifi_opackets)
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return TrafficStats(bytesIn: bytesIn, bytesOut: bytesOut, packetsIn: packetsIn, packetsOut: packetsOut)
    }

    // MARK: Диагностика сети

    /// Простой ping через системную утилиту.
    nonisolated static func ping(host: String, count: Int = 4) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "\(count)", "-W", "2000", host]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? "Нет вывода"
        } catch {
            return "Ошибка: \(error.localizedDescription)"
        }
    }

    /// DNS lookup через системный резолвер.
    nonisolated static func dnsLookup(host: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        task.arguments = ["+short", host]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Нет ответа"
        } catch {
            return "Ошибка: \(error.localizedDescription)"
        }
    }

    /// Проверка порта (TCP connect).
    nonisolated static func checkPort(host: String, port: Int, timeout: TimeInterval = 3) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        task.arguments = ["-z", "-w", "\(Int(timeout))", host, "\(port)"]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
