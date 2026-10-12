import Foundation

class VLESSParser {
    static let shared = VLESSParser()
    
    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("vless://") || link.hasPrefix("trojan://") else { return nil }
        
        let isTrojan = link.hasPrefix("trojan://")
        let prefix = isTrojan ? "trojan://" : "vless://"
        
        var content = link.replacingOccurrences(of: prefix, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Имя (#Remark)
        var name = isTrojan ? "Trojan Server" : "VLESS Server"
        if let hashIndex = content.firstIndex(of: "#") {
            let tagPart = String(content[content.index(after: hashIndex)...])
            name = tagPart.removingPercentEncoding ?? tagPart
            name = name.components(separatedBy: .controlCharacters).joined()
            content = String(content[..<hashIndex])
        }
        
        // Разбор UUID@Host:Port
        guard let atIndex = content.lastIndex(of: "@") else { return nil }
        
        let uuid = String(content[..<atIndex])
        let hostPortPart = String(content[content.index(after: atIndex)...])
        
        var server = ""
        var port = 0
        var paramsStr = ""
        
        if let qIndex = hostPortPart.firstIndex(of: "?") {
            paramsStr = String(hostPortPart[hostPortPart.index(after: qIndex)...])
            let hp = String(hostPortPart[..<qIndex])
            parseHostPort(hp, server: &server, port: &port)
        } else {
            parseHostPort(hostPortPart, server: &server, port: &port)
        }
        
        // Разбор параметров
        let params = parseQuery(paramsStr)
        
        // --- ИСПРАВЛЕНИЕ: Инициализация по частям ---
        var profile = ShadowsocksProfile(name: name, protocolType: isTrojan ? .trojan : .vless)
        profile.server = server
        profile.port = port
        profile.password = uuid
        profile.method = "auto"
        
        // Transport
        profile.network = params["type"] ?? "tcp"
        profile.security = params["security"] ?? "none"
        
        // WebSocket
        profile.wsPath = params["path"]
        profile.wsHost = params["host"]
        
        // gRPC
        profile.grpcServiceName = params["serviceName"]
        if let mode = params["mode"], mode == "multi" {
            profile.grpcMultiMode = true
        }
        
        // TLS / Reality
        profile.sni = params["sni"]
        profile.pbk = params["pbk"]
        profile.fingerprint = params["fp"]
        profile.flow = params["flow"]
        profile.sid = params["sid"]
        profile.spiderX = params["spx"] // SpiderX
        
        return profile
    }
    
    private func parseHostPort(_ input: String, server: inout String, port: inout Int) {
        if let colonIndex = input.lastIndex(of: ":") {
            server = String(input[..<colonIndex])
            server = server.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            port = Int(String(input[input.index(after: colonIndex)...])) ?? 443
        }
    }
    
    private func parseQuery(_ query: String) -> [String: String] {
        var dict: [String: String] = [:]
        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0]
                let value = components[1].removingPercentEncoding ?? components[1]
                dict[key] = value
            }
        }
        return dict
    }
}
