import Foundation

// MARK: - Hysteria2 Parser
// Формат: hysteria2://password@host:port/?sni=...&insecure=1&obfs=salamander&obfs-password=...&alpn=h3&mport=20000-50000#name

class Hysteria2Parser {
    static let shared = Hysteria2Parser()

    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("hysteria2://") || link.hasPrefix("hy2://") else { return nil }
        let prefix = link.hasPrefix("hy2://") ? "hy2://" : "hysteria2://"
        var content = String(link.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)

        // Имя (#Remark)
        var name = "Hysteria2 Server"
        if let hashIndex = content.firstIndex(of: "#") {
            let tagPart = String(content[content.index(after: hashIndex)...])
            name = (tagPart.removingPercentEncoding ?? tagPart).components(separatedBy: .controlCharacters).joined()
            content = String(content[..<hashIndex])
        }

        // userinfo@host:port?params
        guard let atIndex = content.lastIndex(of: "@") else { return nil }
        let password = String(content[..<atIndex]).removingPercentEncoding ?? String(content[..<atIndex])
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

        guard !server.isEmpty, port > 0 else { return nil }
        let params = parseQuery(paramsStr)

        var profile = ShadowsocksProfile(name: name, protocolType: .hysteria2)
        profile.server = server
        profile.port = port
        profile.password = password
        profile.sni = params["sni"]
        profile.allowInsecure = params["insecure"] == "1" || params["insecure"] == "true"
        profile.obfs = params["obfs"]?.lowercased()
        profile.obfsPassword = params["obfs-password"] ?? params["obfs_password"]
        profile.alpn = params["alpn"]
        profile.hy2Ports = params["mport"] ?? params["ports"]
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