import Foundation
import Combine

// MARK: - Реальный тест профиля через прокси
// Запускает Xray на временном порту, делает HEAD 204 через SOCKS (задержка)
// и скачивает 8 МБ (скорость). После теста Xray завершается.

final class ProfileProxyTester: ObservableObject {
    static let shared = ProfileProxyTester()

    @Published private(set) var isTesting = false
    @Published private(set) var latencyMs: Int?
    @Published private(set) var downloadMbps: Double?
    @Published private(set) var statusText: String?
    @Published private(set) var errorText: String?

    private var process: Process?
    private var isCancelled = false

    private static let testPortRange = 15000...16000
    private static let bytesToDownload = 8_000_000

    /// Запускает тест профиля. Результаты обновятся в @Published полях.
    func runTest(profile: ShadowsocksProfile) {
        guard !isTesting else { return }
        isTesting = true
        latencyMs = nil
        downloadMbps = nil
        errorText = nil
        isCancelled = false

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("KnowerXray")
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let configPath = workDir.appendingPathComponent("config_test.json")
        let port = Self.pickFreePort()

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            defer { self.cleanup(port: port, configPath: configPath) }

            guard let binary = self.xrayBinaryPath() else {
                DispatchQueue.main.async { self.fail("Xray binary not found") }
                return
            }

            // 1. Конфиг
            let json = XrayConfigGenerator.shared.createConfig(for: profile, localPort: port)
            do { try json.write(to: configPath, atomically: true, encoding: .utf8) }
            catch {
                DispatchQueue.main.async { self.fail("Config write failed") }
                return
            }

            // 2. Запуск Xray
            let task = Process()
            task.executableURL = binary
            task.arguments = ["-config", configPath.path]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            do { try task.run() } catch {
                DispatchQueue.main.async { self.fail("Xray run failed") }
                return
            }
            self.process = task

            // 3. Ждём порт
            DispatchQueue.main.async { self.statusText = "Starting proxy..." }
            guard self.waitForLocalPort(port: port, timeout: 4.0) else {
                task.terminate()
                DispatchQueue.main.async { self.fail("Proxy did not start") }
                return
            }

            // 4. Задержка (HEAD 204 через SOCKS)
            DispatchQueue.main.async { self.statusText = "Measuring latency..." }
            let latency = self.curlLatency(port: port)
            DispatchQueue.main.async { self.latencyMs = latency }

            guard latency != nil, !self.isCancelled else {
                task.terminate()
                DispatchQueue.main.async { self.fail("No connectivity through proxy") }
                return
            }

            // 5. Скорость (скачивание через SOCKS)
            DispatchQueue.main.async { self.statusText = "Measuring download speed..." }
            let mbps = self.curlSpeed(port: port)
            DispatchQueue.main.async { self.downloadMbps = mbps }
            task.terminate()

            DispatchQueue.main.async {
                self.statusText = nil
                self.isTesting = false
            }
        }
    }

    func cancel() {
        isCancelled = true
        process?.terminate()
    }

    // MARK: - CURL

    /// Задержка через прокси: HEAD https://www.gstatic.com/generate_204.
    private func curlLatency(port: Int) -> Int? {
        let start = Date()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        task.arguments = [
            "-x", "socks5h://127.0.0.1:\(port)",
            "-I", "-m", "8", "--connect-timeout", "3",
            "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "https://www.gstatic.com/generate_204"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let code = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            return (task.terminationStatus == 0 && code == "204") ? ms : nil
        } catch { return nil }
    }

    /// Скорость: скачивание speed.cloudflare.com/__down?bytes=N через SOCKS.
    private func curlSpeed(port: Int) -> Double? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        task.arguments = [
            "-x", "socks5h://127.0.0.1:\(port)",
            "-L", "-m", "12",
            "-s", "-o", "/dev/null", "-w", "%{speed_download}",
            "https://speed.cloudflare.com/__down?bytes=\(Self.bytesToDownload)"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let bytesPerSec = Double(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
                  bytesPerSec > 0 else { return nil }
            // bytes/сек → Мбит/с
            return bytesPerSec * 8 / 1_000_000
        } catch { return nil }
    }

    // MARK: - Helpers

    private func xrayBinaryPath() -> URL? {
        if let bundled = Bundle.main.url(forResource: "xray-core", withExtension: nil) { return bundled }
        let alt = URL(fileURLWithPath: "/usr/local/bin/xray")
        return FileManager.default.isExecutableFile(atPath: alt.path) ? alt : nil
    }

    private func waitForLocalPort(port: Int, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if isCancelled { return false }
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

    private static func pickFreePort() -> Int {
        Int.random(in: testPortRange)
    }

    private func cleanup(port: Int, configPath: URL) {
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: configPath)
    }

    private func fail(_ message: String) {
        print("❌ Proxy test failed: \(message)")
        errorText = message
        isTesting = false
        statusText = nil
    }
}