import Foundation

// MARK: - Простые прокси (SOCKS / HTTP)
// Форматы:
//   socks5://user:pass@host:port#name  |  socks://host:port#name
//   http://user:pass@host:port#name    |  https://user:pass@host:port#name

class SOCKSProxyParser {
    static let shared = SOCKSProxyParser()

    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("socks5://") || link.hasPrefix("socks://") else { return nil }
        let prefix = link.hasPrefix("socks5://") ? "socks5://" : "socks://"
        return ProxylikeParser.shared.parse(link: link, prefix: prefix, protocolType: .socks, defaultName: "SOCKS Server")
    }
}

class HTTPProxyParser {
    static let shared = HTTPProxyParser()

    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("http://") || link.hasPrefix("https://"), link.contains("@") else { return nil }
        let prefix = link.hasPrefix("https://") ? "https://" : "http://"
        let isTLS = link.hasPrefix("https://")
        guard var profile = ProxylikeParser.shared.parse(link: link, prefix: prefix, protocolType: .http, defaultName: "HTTP Proxy Server") else { return nil }
        profile.security = isTLS ? "tls" : nil
        return profile
    }
}

final class ProxylikeParser {
    static let shared = ProxylikeParser()

    func parse(link: String, prefix: String, protocolType: ProxyProtocol, defaultName: String) -> ShadowsocksProfile? {
        var content = String(link.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)

        var name = defaultName
        if let hashIndex = content.firstIndex(of: "#") {
            let tagPart = String(content[content.index(after: hashIndex)...])
            name = (tagPart.removingPercentEncoding ?? tagPart).components(separatedBy: .controlCharacters).joined()
            content = String(content[..<hashIndex])
        }

        var server = ""
        var port = 0
        var user = ""
        var password = ""

        if let atIndex = content.lastIndex(of: "@") {
            let userInfo = content[..<atIndex].removingPercentEncoding ?? String(content[..<atIndex])
            let infoParts = String(userInfo).split(separator: ":", maxSplits: 1).map(String.init)
            // Пустой userinfo (socks://@host:port) даёт [] — не падаем, а сохраняем пустые учётные данные.
            user = infoParts.isEmpty ? "" : infoParts[0]
            if infoParts.count > 1 { password = infoParts[1] }
            parseHostPort(String(content[content.index(after: atIndex)...]), server: &server, port: &port)
        } else {
            parseHostPort(content, server: &server, port: &port)
        }

        guard !server.isEmpty, port > 0 else { return nil }

        var profile = ShadowsocksProfile(name: name, protocolType: protocolType)
        profile.server = server
        profile.port = port
        profile.method = user
        profile.password = password
        profile.network = "tcp"
        profile.security = nil
        return profile
    }

    private func parseHostPort(_ input: String, server: inout String, port: inout Int) {
        let cleanInput = String(input.prefix { $0 != "?" })
        guard let colonIndex = cleanInput.lastIndex(of: ":") else {
            server = cleanInput.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            return
        }
        server = String(cleanInput[..<colonIndex]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        if let p = Int(String(cleanInput[cleanInput.index(after: colonIndex)...])), (1...65535).contains(p) {
            port = p
        }
    }
}