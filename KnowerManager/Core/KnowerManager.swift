import Foundation
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

// --- МОДЕЛИ ДЛЯ ЧЕКЕРА И СТРАТЕГИЙ ---
struct TestStrategy {
    let name: String
    let args: String
}

// 1. РЕЖИМЫ МАРШРУТИЗАЦИИ (Global, List, Exclude)
enum RoutingMode: Int, CaseIterable, Identifiable {
    case global = 0
    case onlyList = 1
    case exclude = 2
    
    var id: Int { self.rawValue }
}

enum BypassStrategy: String, CaseIterable, Identifiable {
    case split2, disorder, fake, oob, split1, flowseal, tlsRec, seqOverl, multiDisorder, auto, custom
    var id: String { self.rawValue }
    
    var localizedName: String {
        switch self {
        case .split2: return SettingsManager.shared.t(.stratSplit2)
        case .disorder: return SettingsManager.shared.t(.stratDisorder)
        case .fake: return SettingsManager.shared.t(.stratFake)
        case .oob: return SettingsManager.shared.t(.stratOOB)
        case .split1: return SettingsManager.shared.t(.stratSplit1)
        case .flowseal: return SettingsManager.shared.t(.stratFlowseal)
        case .tlsRec: return SettingsManager.shared.t(.stratTlsRec)
        case .seqOverl: return SettingsManager.shared.t(.stratseqOverl)
        case .multiDisorder: return SettingsManager.shared.t(.stratmultiDisorder)
        case .auto: return SettingsManager.shared.t(.stratAuto)
        case .custom: return SettingsManager.shared.t(.stratCustom)
        }
    }
    
    var args: String {
        switch self {
        case .split2: return "--split-pos=2 --hostcase"
        case .disorder: return "--disorder --split-pos=2 --hostcase"
        case .fake: return "--disorder --split-pos=2 --oob --hostcase"
        case .oob: return "--oob --split-pos=2 --hostcase"
        case .split1: return "--split-pos=1 --hostcase"
        case .flowseal: return "--disorder --split-pos=2 --mss=1100 --hostcase"
        case .tlsRec: return "--tlsrec=sni+2 --split-pos=sni --hostcase"
        case .seqOverl: return "--dpi-desync=split --dpi-desync-split-seqovl=1 --dpi-desync-split-pos=2 --hostcase"
        case .multiDisorder: return "--dpi-desync=multidisorder --dpi-desync-split-pos=2 --mss=1100 --hostcase"
        case .auto: return KnowerManager.shared.foundBestArgs
        case .custom: return KnowerManager.shared.customArgs
        }
    }
}

class KnowerManager: ObservableObject {
    static let shared = KnowerManager()
    
    private var settings = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // --- ПАРОЛЬ (Кэш в памяти) ---
    private var cachedPassword: String?
    
    // --- CUSTOM ARGS & ENDPOINT ---
    @Published var customArgs: String = "" { didSet { UserDefaults.standard.set(customArgs, forKey: "CustomArgs") } }
    @Published var customEndpoint: String = "" { didSet { UserDefaults.standard.set(customEndpoint, forKey: "CustomEndpoint") } }
    
    // --- WI-FI GATEWAY ---
    @Published var isGatewayEnabled: Bool = false {
        didSet {
            updateFirewallRulesIfNeeded()
        }
    }
    
    // --- HOSTLIST LOGIC (UPDATED) ---
    // Заменили Bool на RoutingMode
    @Published var routingMode: RoutingMode = .onlyList {
        didSet { UserDefaults.standard.set(routingMode.rawValue, forKey: "RoutingMode") }
    }
    @Published var userDomains: [String] = [] { didSet { saveDomainsToDisk() } }
    
    // --- STATE ---
    @Published var isRunning = false
    @Published var isFileReady = false
    @Published var isDownloading = false
    @Published var isChecking = false
    @Published var statusMessage = ""
    @Published var consoleOutput = ""
    @Published var selectedStrategy: BypassStrategy = .disorder
    @Published var foundBestArgs: String = "--disorder --split-pos=2 --hostcase"
    
    private let tpwsFileName = "tpws"
    private let hostlistFileName = "list-general.txt"
    private let localPort = "988"
    private let testPort = "12988"
    private let logPath = "/tmp/KnowerManager/tpws.log"
    private var logTimer: Timer?
    
    private var workingDir: URL { return URL(fileURLWithPath: "/tmp/KnowerManager", isDirectory: true) }
    private var tpwsPath: URL { return workingDir.appendingPathComponent(tpwsFileName) }
    private var hostlistPath: URL { return workingDir.appendingPathComponent(hostlistFileName) }
    
    private let targetsToCheck = [
        "https://discord.com", "https://www.youtube.com", "https://twitter.com",
        "https://www.instagram.com", "https://rutracker.org"
    ]
    
    private let strategiesToCheck: [TestStrategy] = [
        TestStrategy(name: "Disorder Standard", args: "--disorder --split-pos=2 --hostcase"),
        TestStrategy(name: "Clash Mode", args: "--disorder --split-pos=2 --mss=1100 --split-any-protocol --hostcase"),
        TestStrategy(name: "Split 2 Safe", args: "--split-pos=2 --hostcase --mss=1200"),
        TestStrategy(name: "OOB Simple", args: "--oob --split-pos=2 --hostcase"),
        TestStrategy(name: "BadSeq Fix", args: "--disorder --split-pos=2 --badseq --hostcase"),
        TestStrategy(name: "TLS Record Split", args: "--tlsrec=sni+2 --split-pos=2 --hostcase"),
        TestStrategy(name: "Fake (OOB+Disorder)", args: "--disorder --split-pos=2 --oob --hostcase"),
        TestStrategy(name: "Flowseal", args: "--disorder --split-pos=2 --mss=1100 --hostcase"),
        TestStrategy(name: "TLS Split (Strong)", args: "--tlsrec=sni+2 --split-pos=sni --hostcase"),
        TestStrategy(name: "Discord Fake", args: "--disorder --split-pos=2 --oob --hostcase --mss=1200"),
        TestStrategy(name: "Simple Split", args: "--split-pos=2 --hostcase"),
        TestStrategy(name: "Aggressive Split", args: "--split-pos=host --split-pos=sni --disorder --hostcase"),
        TestStrategy(name: "Seq Overlap", args: "--dpi-desync=split --dpi-desync-split-seqovl=1 --dpi-desync-split-pos=2 --hostcase"),
        TestStrategy(name: "Multi Disorder", args: "--dpi-desync=multidisorder --dpi-desync-split-pos=2 --mss=1100 --hostcase")
    ]
    
    private init() {
        checkFileStatus()
        updateStatusMessage()
        loadDomainsFromDisk()
        
        // Загрузка RoutingMode
        if UserDefaults.standard.object(forKey: "RoutingMode") == nil {
            self.routingMode = .onlyList // По умолчанию whitelist
        } else {
            let val = UserDefaults.standard.integer(forKey: "RoutingMode")
            self.routingMode = RoutingMode(rawValue: val) ?? .onlyList
        }
        
        customArgs = UserDefaults.standard.string(forKey: "CustomArgs") ?? ""
        customEndpoint = UserDefaults.standard.string(forKey: "CustomEndpoint") ?? ""
        
        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusMessage()
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    // --- МЕТОД ДЛЯ СБРОСА ПАРОЛЯ ---
    func forgetPassword() {
        cachedPassword = nil
        KeychainHelper.shared.delete()
        print("Password forgotten.")
    }
    
    // --- STATUS UPDATES ---
    
    func updateStatusMessage() {
        if isDownloading { statusMessage = settings.t(.statusDownloading) }
        else if isChecking { statusMessage = settings.t(.checking) }
        else if isRunning { statusMessage = settings.t(.statusActive) }
        else if !isFileReady { statusMessage = settings.t(.statusMissing) }
        else { statusMessage = settings.t(.statusReady) }
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: workingDir.path)
    }
    
    func checkFileStatus() {
        let exists = FileManager.default.fileExists(atPath: tpwsPath.path)
        if exists {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: tpwsPath.path)[.size] as? Int64) ?? 0
            if fileSize < 10000 || isFileActuallyHtml(path: tpwsPath) {
                isFileReady = false; updateStatusMessage()
            } else {
                isFileReady = true; updateStatusMessage()
            }
        } else {
            isFileReady = false; updateStatusMessage()
        }
    }
    
    private func isFileActuallyHtml(path: URL) -> Bool {
        guard let data = try? Data(contentsOf: path), let content = String(data: data.prefix(50), encoding: .utf8) else { return false }
        return content.contains("<!DOCTYPE") || content.contains("<html")
    }
    
    // --- HOSTLIST ---
    
    func addDomain(_ domain: String) {
        let clean = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/", with: "")
        if !clean.isEmpty && !userDomains.contains(clean) { userDomains.append(clean) }
    }
    
    func removeDomain(at offsets: IndexSet) { userDomains.remove(atOffsets: offsets) }
    
    private func saveDomainsToDisk() {
        UserDefaults.standard.set(userDomains, forKey: "UserDomains")
        // useHostlist больше не сохраняем здесь, так как есть RoutingMode
    }
    
    private func loadDomainsFromDisk() {
        if let s = UserDefaults.standard.stringArray(forKey: "UserDomains") { userDomains = s }
        else { userDomains = ["youtube.com", "googlevideo.com", "discord.com", "discord.gg", "twitter.com", "x.com", "instagram.com", "facebook.com"] }
    }
    
    private func generateHostlistFile() { let c = userDomains.joined(separator: "\n"); try? c.write(to: hostlistPath, atomically: true, encoding: .utf8) }
    
    // --- ИМПОРТ, ЭКСПОРТ И ЗАГРУЗКА ---

    // 1. Импорт (Загрузка из файла)
    func importHostlist() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.plainText, .text]
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.message = self.settings.t(.importMessage)
            
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let lines = content.components(separatedBy: .newlines)
                    
                    var addedCount = 0
                    for line in lines {
                        if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let oldCount = self.userDomains.count
                            self.addDomain(line)
                            if self.userDomains.count > oldCount {
                                addedCount += 1
                            }
                        }
                    }
                    print("✅ Imported domains: \(addedCount)")
                } catch {
                    print("❌ Error reading file: \(error.localizedDescription)")
                }
            }
        }
    }

    // 2. Экспорт (Сохранение в файл)
    func exportHostlist() {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "hostlist.txt"
            panel.message = self.settings.t(.exportMessage)
            
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    let content = self.userDomains.joined(separator: "\n")
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ List saved")
                } catch {
                    print("❌ Error saving: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 3. Загрузка по URL (НОВОЕ)
    func downloadHostlist(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                var addedCount = 0
                DispatchQueue.main.async {
                    let oldCount = self.userDomains.count
                    for line in lines {
                        self.addDomain(line)
                    }
                    addedCount = self.userDomains.count - oldCount
                    self.appendLog("📥 Downloaded from URL: \(addedCount) new domains.")
                    
                    if addedCount > 0 {
                        self.statusMessage = "\(self.settings.t(.downloadSuccess)) \(addedCount)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Download error: \(error.localizedDescription)")
                    self.statusMessage = "\(self.settings.t(.downloadError)): \(error.localizedDescription)"
                }
            }
        }
    }
    
    // --- CHECKER ---
    
    func runChecker() {
        guard isFileReady, !isChecking else { return }
        isChecking = true; updateStatusMessage()
        appendLog("\n" + settings.t(.logScanStarted))
        
        DispatchQueue.global(qos: .userInitiated).async {
            var best: TestStrategy? = nil; var maxScore = -1
            for strategy in self.strategiesToCheck {
                DispatchQueue.main.async { self.appendLog("--> \(self.settings.t(.logTest)): \(strategy.name)") }
                let pid = self.runShell("'\(self.tpwsPath.path)' --port=\(self.testPort) --socks --bind-addr=127.0.0.1 \(strategy.args) > /dev/null 2>&1 & echo $!").trimmingCharacters(in: .whitespacesAndNewlines)
                Thread.sleep(forTimeInterval: 0.5)
                var score = 0
                for url in self.targetsToCheck {
                    let res = self.runShell("curl -k -s -o /dev/null -w \"%{http_code}\" --socks5 127.0.0.1:\(self.testPort) -m 2 \(url)").trimmingCharacters(in: .whitespacesAndNewlines)
                    if ["200","301","302"].contains(res) { score += 1 }
                }
                _ = self.runShell("kill -9 \(pid)")
                let pct = Double(score)/5.0*100
                DispatchQueue.main.async { self.appendLog("   \(self.settings.t(.logResult)): \(score)/5 (\(Int(pct))%) \(score >= 4 ? "✅" : (score>0 ? "⚠️" : "❌"))") }
                if score > maxScore { maxScore = score; best = strategy }
                if pct >= 80 { break }
            }
            DispatchQueue.main.async {
                self.isChecking = false
                if let best = best, maxScore > 0 {
                    self.foundBestArgs = best.args; self.selectedStrategy = .auto
                    self.statusMessage = "\(self.settings.t(.autoFound)): \(best.name)"
                    self.appendLog("\n🏆 \(self.settings.t(.logWinner)): \(best.name)")
                } else {
                    self.statusMessage = self.settings.t(.notFound)
                    self.appendLog("\n❌ \(self.settings.t(.logNoStrategy))")
                }
            }
        }
    }
    
    // --- BUILD ---
    
    func downloadTpws() {
        isDownloading = true; updateStatusMessage(); ensureDirectoryExists()
        DispatchQueue.global(qos: .userInitiated).async {
            // `set -e` останавливает цепочку на первой ошибке, чтобы неудачная
            // сборка не отображалась как успех. Всю группу направляем в один поток.
            let res = self.runShell("set -e; { rm -rf /tmp/k_src; git clone --depth 1 https://github.com/bol-van/zapret.git /tmp/k_src; cd /tmp/k_src && make mac; cp -f /tmp/k_src/tpws/tpws '\(self.tpwsPath.path)'; chmod +x '\(self.tpwsPath.path)'; } 2>&1")
            DispatchQueue.main.async {
                self.isDownloading = false
                if FileManager.default.fileExists(atPath: self.tpwsPath.path) {
                    self.checkFileStatus()
                } else {
                    self.appendLog("Error: \(res)")
                }
                self.updateStatusMessage()
            }
        }
    }
    
    func selectLocalFile() {
        DispatchQueue.main.async {
            let p = NSOpenPanel(); p.canChooseFiles = true
            if p.runModal() == .OK, let u = p.url {
                let fm = FileManager.default
                // copyItem падает, если файл назначения уже существует,
                // поэтому сначала удаляем старый бинарник.
                try? fm.removeItem(at: self.tpwsPath)
                do {
                    try fm.copyItem(at: u, to: self.tpwsPath)
                } catch {
                    self.appendLog("Error: \(error.localizedDescription)")
                }
                _ = self.runShell("chmod +x '\(self.tpwsPath.path)'")
                self.checkFileStatus()
            }
        }
    }
    
    // --- KILL SWITCH ---
    
    func enableKillSwitch() {
        print("🛡 Activating Kill Switch...")
        let pfRules = """
        set block-policy drop
        pass quick on lo0 all
        pass quick on bridge100 all
        pass out quick from any to 192.168.0.0/16
        pass out quick from any to 10.0.0.0/8
        pass out quick from any to 172.16.0.0/12
        block drop out quick from any to any
        """
        let script = "echo '\(pfRules)' | pfctl -E -f -"
        runAsAdmin(script: script) { s, _ in if s { print("Kill Switch Enabled") } }
    }
    
    func disableKillSwitch() {
        print("🛡 Deactivating Kill Switch...")
        let script = "pfctl -f /etc/pf.conf"
        runAsAdmin(script: script) { _, _ in }
    }
    
    // --- SERVICE START/STOP ---
    
    func toggleService() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        if isRunning { stopKnower() } else { startKnower() }
    }
    
    func startKnower() {
        ensureDirectoryExists(); checkFileStatus(); guard isFileReady else { return }
        
        // Генерация списка обязательна для режимов List и Exclude
        if !userDomains.isEmpty { generateHostlistFile() }
        
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
        statusMessage = settings.t(.statusStarting)
        
        var args = selectedStrategy.args
        
        //
        // ЛОГИКА РЕЖИМОВ (Global / OnlyList / Exclude)
        switch routingMode {
        case .global:
            // Глобальный режим: параметры списка не добавляются
            break
        case .onlyList:
            // Только список (Whitelist)
            args += " --hostlist='\(hostlistPath.path)'"
        case .exclude:
            // Исключения (Blacklist)
            args += " --hostlist-exclude='\(hostlistPath.path)'"
        }
        
        let dns = settings.dnsServer.servers
        
        let script = """
        killall -9 tpws 2>/dev/null
        rm -f '\(logPath)'; touch '\(logPath)'; chmod 666 '\(logPath)'
        xattr -cr '\(tpwsPath.path)'; chmod +x '\(tpwsPath.path)'
        
        echo ">>> Starting SOCKS Service (0.0.0.0:\(localPort))..." >> '\(logPath)'
        '\(tpwsPath.path)' --user=root --port=\(localPort) --socks --bind-addr=0.0.0.0 \(args) --debug=1 >> '\(logPath)' 2>&1 &
        
        networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do
            if networksetup -getinfo "$s" | grep -q "IP address"; then
                echo "Setup Proxy: $s" >> '\(logPath)'
                networksetup -setsocksfirewallproxy "$s" 127.0.0.1 \(localPort)
                networksetup -setsocksfirewallproxystate "$s" on
                if [ "\(dns)" != "Empty" ]; then networksetup -setdnsservers "$s" \(dns); fi
            fi
        done
        """
        
        runAsAdmin(script: script) { success, out in
            if success {
                self.isRunning = true
                self.updateStatusMessage()
                self.startLogReader()
                self.applyFirewallRules()
                
                if self.isGatewayEnabled, let ip = self.getBridgeIP() {
                    PacServer.shared.startServer(bridgeIP: ip, socksPort: self.localPort)
                    self.appendLog("\(self.settings.t(.logPacServer)) http://\(ip):8080/proxy.pac")
                }
            } else {
                self.statusMessage = self.settings.t(.statusError)
                self.appendLog(out)
                self.stopKnower(forceKillSwitch: false)
            }
        }
    }
    
    func updateFirewallRulesIfNeeded() {
        applyFirewallRules()
        
        if isRunning {
            appendLog(settings.t(.logFwUpdated))
        } else {
            print("Firewall rules updated (Service is stopped).")
        }
    }
    
    func getBridgeIP() -> String? {
        let out = runShell("ifconfig bridge100 | grep 'inet ' | awk '{print $2}'").trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? nil : out
    }
    
    private func applyFirewallRules() {
        var gatewayRules = ""
        if isGatewayEnabled {
            gatewayRules += "pass quick on bridge100 proto udp from any to any port 53\n"
            gatewayRules += "block drop quick on bridge100 proto udp all\n"
            gatewayRules += "pass quick on bridge100 proto tcp all\n"
            gatewayRules += "pass quick on bridge100 proto icmp all\n"
        }
        
        var macBlockRules = ""
        if settings.fixYoutube { macBlockRules += "block return out quick proto udp from any to any port 443\n" }
        if settings.fixDiscord { macBlockRules += "block return out quick proto udp from any to any port 50000:65535\n" }
        macBlockRules += "block return out quick proto udp from any to any port 3478\n"
        
        let pfContent = """
        # Options
        set block-policy drop
        set skip on lo0
        scrub-anchor "com.apple/*"
        nat-anchor "com.apple/*"
        rdr-anchor "com.apple/*"
        dummynet-anchor "com.apple/*"
        anchor "com.apple/*"
        load anchor "com.apple" from "/etc/pf.anchors/com.apple"
        
        \(gatewayRules)
        
        pass quick proto tcp user { root }
        pass quick proto udp user { root }
        pass quick proto udp from any to any port 2408
        pass quick proto udp from any to any port 53
        pass quick proto tcp from any to any port 53
        
        \(macBlockRules)
        pass out all
        """
        
        let pfPath = workingDir.appendingPathComponent("knowermanager_pf.conf").path
        try? pfContent.write(toFile: pfPath, atomically: true, encoding: .utf8)
        
        let script = "chmod 644 '\(pfPath)' && pfctl -E -f '\(pfPath)' 2>/dev/null"
        runAsAdmin(script: script) { _, _ in }
        
        if isGatewayEnabled { appendLog(settings.t(.logGatewayBlocked)) }
    }
    
    func stopKnower(forceKillSwitch: Bool? = nil) {
        stopLogReader()
        PacServer.shared.stopServer()
        
        var script = """
        networksetup -listallnetworkservices | grep -v 'An asterisk' | while read s; do
            networksetup -setsocksfirewallproxystate "$s" off
            networksetup -setdnsservers "$s" "Empty"
        done
        killall -9 tpws
        """
        
        let shouldUseKillSwitch = forceKillSwitch ?? settings.killSwitchEnabled
        if shouldUseKillSwitch {
            script += "\n"
            let pfRules = """
            set block-policy drop
            pass quick on lo0 all
            pass quick on bridge100 all
            pass out quick from any to 192.168.0.0/16
            pass out quick from any to 10.0.0.0/8
            pass out quick from any to 172.16.0.0/12
            block drop out quick from any to any
            """
            let blockPath = "/tmp/KnowerManager/block_rules.conf"
            try? pfRules.write(toFile: blockPath, atomically: true, encoding: .utf8)
            script += "pfctl -E -f '\(blockPath)' 2>/dev/null"
        } else {
            script += "\npfctl -f /etc/pf.conf 2>/dev/null"
        }
        
        runAsAdmin(script: script) { s, _ in
            if s {
                self.isRunning = false
                self.updateStatusMessage()
                if shouldUseKillSwitch { self.statusMessage = self.settings.t(.statusStoppedKS) }
            }
        }
    }
    
    // --- LOG READER ---
    private func startLogReader() {
        logTimer?.invalidate()
        logTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let c = try? String(contentsOfFile: self.logPath, encoding: .utf8) {
                let s = String(c.suffix(2000))
                DispatchQueue.main.async {
                    if self.consoleOutput.suffix(50) != s.suffix(50) { self.consoleOutput = s }
                }
            }
        }
    }
    private func stopLogReader() { logTimer?.invalidate(); logTimer = nil }
    
    // --- HELPER SHELL ---
    private func runShell(_ c: String) -> String {
        let t = Process()
        let p = Pipe()
        t.executableURL = URL(fileURLWithPath: "/bin/bash")
        t.arguments = ["-c", c]
        t.standardOutput = p
        t.standardInput = FileHandle.nullDevice
        do {
            try t.run()
        } catch {
            print("runShell failed: \(error)")
            return ""
        }
        // Вычитываем вывод ДО waitUntilExit: иначе при выводе больше буфера pipe
        // дочерний процесс блокируется на записи, а родитель — на ожидании.
        let data = p.fileHandleForReading.readDataToEndOfFile()
        t.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func appendLog(_ t: String) { consoleOutput += "[\(Date())] \(t)\n" }
    
    // 1. Эта функция запускает команды через sudo и сама подставляет пароль
    func runAsAdmin(script: String, completion: @escaping (Bool, String) -> Void) {
        getPassword { password in
            guard let password = password else {
                DispatchQueue.main.async { completion(false, self.settings.t(.passCancelled)) }
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                task.arguments = ["-S", "/bin/bash", "-c", script]
                
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                
                task.standardInput = inputPipe
                task.standardOutput = outputPipe
                // stderr объединяем с stdout: так проще гарантированно вычитать оба потока
                // без риска взаимоблокировки, при этом текст ошибок sudo остаётся доступен.
                task.standardError = outputPipe
                
                do {
                    try task.run()
                    
                    if let passData = "\(password)\n".data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(passData)
                    }
                    inputPipe.fileHandleForWriting.closeFile()
                    
                    // Сначала вычитываем весь вывод, затем дожидаемся завершения процесса.
                    let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    task.waitUntilExit()
                    
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let errorMsg = output
                    
                    DispatchQueue.main.async {
                        if task.terminationStatus == 0 {
                            completion(true, output)
                        } else {
                            if errorMsg.contains("try again") || errorMsg.contains("incorrect") {
                                self.cachedPassword = nil
                                KeychainHelper.shared.delete()
                                completion(false, self.settings.t(.passIncorrect))
                            } else {
                                completion(false, errorMsg.isEmpty ? output : errorMsg)
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async { completion(false, error.localizedDescription) }
                }
            }
        }
    }
    
    // 2. Логика поиска пароля
    private func getPassword(completion: @escaping (String?) -> Void) {
        if let mem = cachedPassword { completion(mem); return }
        
        if let saved = KeychainHelper.shared.read() {
            self.cachedPassword = saved
            completion(saved)
            return
        }
        
        DispatchQueue.main.async {
            self.showCustomPasswordPrompt(completion: completion)
        }
    }
    
    // 3. Кастомное окно ввода (вместо системного)
    private func showCustomPasswordPrompt(completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = settings.t(.passTitle)
        alert.informativeText = settings.t(.passDesc)
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: settings.t(.btnOK))
        alert.addButton(withTitle: settings.t(.btnCancel))
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = settings.t(.passPlaceholder)
        
        let checkbox = NSButton(checkboxWithTitle: settings.t(.passRemember), target: nil, action: nil)
        checkbox.state = .off
        
        let stack = NSStackView(views: [input, checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.frame = NSRect(x: 0, y: 0, width: 220, height: 50)
        
        alert.accessoryView = stack
        alert.window.initialFirstResponder = input
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let pass = input.stringValue
            if !pass.isEmpty {
                self.cachedPassword = pass
                if checkbox.state == .on { KeychainHelper.shared.save(pass) }
                completion(pass)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}
