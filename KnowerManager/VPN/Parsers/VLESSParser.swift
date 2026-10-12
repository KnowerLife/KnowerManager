import Foundation

class VLESSParser {
    static let shared = VLESSParser()
    
    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("vless://") || link.hasPrefix("trojan://") else { return nil }
        
        let isTrojan = link.hasPrefix("trojan://")
        let prefix = isTrojan ? "trojan://" : "vless://"
        
        var content = String(link.dropFirst(prefix.count))
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
        
        // Проверяем, что адрес разобран корректно (порт по умолчанию 443).
        guard !server.isEmpty else { return nil }
        if port == 0 { port = 443 }
        
        // --- ИСПРАВЛЕНИЕ: Инициализация по частям ---
        var profile = ShadowsocksProfile(name: name, protocolType: isTrojan ? .trojan : .vless)
        profile.server = server
        profile.port = port
        profile.password = uuid
        profile.method = "auto"
        
        // Transport
        profile.network = params["type"] ?? "tcp"
        profile.security = params["security"] ?? "none"
        
        // WebSocket / HTTPUpgrade / SplitHTTP / H2
        profile.wsPath = params["path"]
        profile.wsHost = params["host"]
        
        // KCP / QUIC
        profile.kcpSeed = params["seed"]
        if profile.network == "quic" {
            profile.quicSecurity = params["quicSecurity"] ?? params["security"] ?? "none"
            profile.quicKey = params["key"]
        }
        
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
        
        // ALPN
        if let alpn = params["alpn"], !alpn.isEmpty {
            profile.alpn = alpn
        }
        
        return profile
    }
    
    private func parseHostPort(_ input: String, server: inout String, port: inout Int) {
        guard let colonIndex = input.lastIndex(of: ":") else {
            server = input.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            return
        }
        server = String(input[..<colonIndex])
        server = server.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        if let p = Int(String(input[input.index(after: colonIndex)...])), (1...65535).contains(p) {
            port = p
        }
    }
    
    private func parseQuery(_ query: String) -> [String: String] {
        var dict: [String: String] = [:]
        for pair in query.split(separator: "&") {
            // split по "=" с ограничением: значение может само содержать "="
            // (base64 с паддингом, spiderX и т.п.) — тогда old-код его выбрасывал.
            guard let eq = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[..<eq])
            let rawValue = String(pair[pair.index(after: eq)...])
            dict[key] = rawValue.removingPercentEncoding ?? rawValue
        }
        return dict
    }
}
