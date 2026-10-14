import Foundation

// MARK: - TUIC Parser
// Формат: tuic://uuid:password@host:port/?sni=...&alpn=h3&congestion_control=bbr&udp_relay_mode=native&allow_insecure=1#name

class TUICParser {
    static let shared = TUICParser()

    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("tuic://") else { return nil }
        var content = String(link.dropFirst("tuic://".count)).trimmingCharacters(in: .whitespacesAndNewlines)

        var name = "TUIC Server"
        if let hashIndex = content.firstIndex(of: "#") {
            let tagPart = String(content[content.index(after: hashIndex)...])
            name = (tagPart.removingPercentEncoding ?? tagPart).components(separatedBy: .controlCharacters).joined()
            content = String(content[..<hashIndex])
        }

        guard let atIndex = content.lastIndex(of: "@") else { return nil }
        let userInfo = String(content[..<atIndex]).removingPercentEncoding ?? String(content[..<atIndex])
        let hostPortPart = String(content[content.index(after: atIndex)...])

        var server = ""
        var port = 0
        var paramsStr = ""
        if let qIndex = hostPortPart.firstIndex(of: "?") {
            paramsStr = String(hostPortPart[hostPortPart.index(after: qIndex)...])
            parseHostPort(String(hostPortPart[..<qIndex]), server: &server, port: &port)
        } else {
            parseHostPort(hostPortPart, server: &server, port: &port)
        }

        guard !server.isEmpty, port > 0, !userInfo.isEmpty else { return nil }

        // userInfo = uuid[:password]
        let parts = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
        let uuid = parts[0]
        let tuicPassword = parts.count > 1 ? parts[1] : nil

        let params = parseQuery(paramsStr)

        var profile = ShadowsocksProfile(name: name, protocolType: .tuic)
        profile.server = server
        profile.port = port
        profile.password = uuid
        profile.tuicPassword = tuicPassword
        profile.sni = params["sni"]
        profile.allowInsecure = params["allow_insecure"] == "1"
        profile.alpn = params["alpn"]
        profile.tuicCongestion = params["congestion_control"]
        profile.tuicUDPRelayMode = params["udp_relay_mode"]
        profile.flow = params["flow"] // "xtls-rprx-vision" (uTLS fingerprint)
        profile.fingerprint = params["fp"] ?? "chrome"
        return profile
    }

    private func parseHostPort(_ rawInput: String, server: inout String, port: inout Int) {
        guard let colonIndex = rawInput.lastIndex(of: ":") else {
            server = rawInput.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            return
        }
        server = String(rawInput[..<colonIndex]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        // Отсекаем путь/query у порта (формат host:port/?...).
        let portPart = String(rawInput[rawInput.index(after: colonIndex)...].prefix { $0 != "?" && $0 != "/" })
        if let p = Int(portPart), (1...65535).contains(p) {
            port = p
        }
    }

    private func parseQuery(_ query: String) -> [String: String] {
        var dict: [String: String] = [:]
        for pair in query.split(separator: "&") {
            guard let eq = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[..<eq])
            let rawValue = String(pair[pair.index(after: eq)...])
            dict[key] = rawValue.removingPercentEncoding ?? rawValue
        }
        return dict
    }
}