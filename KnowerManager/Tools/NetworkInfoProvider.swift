import Foundation

struct NetworkInterfaceInfo {
    let name: String
    let ipv4: String
    let ipv6: String
    let mac: String
    let gateway: String
    let dns: String
}

enum NetworkInfoProvider {
    static func getActiveInterface() -> NetworkInterfaceInfo {
        // Получаем активный интерфейс (en0/en1 и др)
        let ipv4 = shellOutput("/sbin/ifconfig | grep -A 1 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'")
        let ipv6 = shellOutput("/sbin/ifconfig | grep 'inet6 ' | grep -v 'fe80' | head -1 | awk '{print $2}'")
        let name = shellOutput("/usr/sbin/netstat -rn | grep default | head -1 | awk '{print $6}'") // interface for default route
        let gateway = shellOutput("/usr/sbin/netstat -rn | grep default | head -1 | awk '{print $2}'")
        let mac = shellOutput("/sbin/ifconfig en0 2>/dev/null | grep ether | awk '{print $2}'")
        let dns = shellOutput("scutil --dns | grep 'nameserver' | head -2 | awk '{print $3}' | tr '\n' ' '")
        
        return NetworkInterfaceInfo(
            name: name.isEmpty ? "en0" : name,
            ipv4: ipv4.isEmpty ? "-" : ipv4,
            ipv6: ipv6.isEmpty ? "-" : ipv6,
            mac: mac.isEmpty ? "-" : mac,
            gateway: gateway.isEmpty ? "-" : gateway,
            dns: dns.isEmpty ? "-" : dns
        )
    }
    
    private static func shellOutput(_ cmd: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
