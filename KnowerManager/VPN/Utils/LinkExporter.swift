import Foundation

// MARK: - Обратная сериализация профиля в share-ссылку
// Форматы зеркалируют LinkParser, чтобы экспорт → импорт давал тот же профиль.
// Используется для генерации QR-кода и копирования ссылки.

enum LinkExporter {

    private static func enc(_ s: String) -> String {
        // Percent-кодирование значений URI-параметров и тега (#name).
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// Создаёт share-ссылку для профиля или nil, если профиль не полон.
    static func exportURL(_ profile: ShadowsocksProfile) -> String? {
        guard !profile.server.isEmpty, profile.port > 0 else { return nil }
        switch profile.protocolType {
        case .vless:
            return vlessURL(profile, prefix: "vless")
        case .trojan:
            return trojanURL(profile)
        case .vmess:
            return vmessURL(profile)
        case .shadowsocks:
            return shadowsocksURL(profile)
        case .hysteria2:
            return hysteria2URL(profile)
        case .tuic:
            return tuicURL(profile)
        case .socks:
            return proxyURL(profile, prefix: "socks5")
        case .http:
            // HTTP-прокси без авторизации тоже должен проходить импорт:
            // пустой userinfo с '@' позволяет парсеру (LinkParser) распознать ссылку.
            return proxyURL(profile, prefix: "http")
        }
    }

    // MARK: - VLESS / Trojan

    private static func vlessURL(_ p: ShadowsocksProfile, prefix: String) -> String? {
        guard let uuid = p.password, !uuid.isEmpty else { return nil }
        return "\(prefix)://\(uuid)@\(hostPort(p))\(vlessParams(p))#\(enc(p.name))"
    }

    private static func trojanURL(_ p: ShadowsocksProfile) -> String? {
        guard let password = p.password, !password.isEmpty else { return nil }
        return "trojan://\(enc(password))@\(hostPort(p))\(vlessParams(p))#\(enc(p.name))"
    }

    private static func vlessParams(_ p: ShadowsocksProfile) -> String {
        var q: [String] = []
        q.append("type=\(p.network ?? "tcp")")
        q.append("security=\(p.security ?? "none")")

        if let path = p.wsPath, !path.isEmpty, p.network?.hasPrefix("tcp") == false {
            q.append("path=\(path)")
        }
        if let host = p.wsHost, !host.isEmpty {
            q.append("host=\(host)")
        }
        if p.network == "grpc", let svc = p.grpcServiceName, !svc.isEmpty {
            q.append("serviceName=\(svc)")
            if p.grpcMultiMode == true { q.append("mode=multi") }
        }
        if p.network == "kcp", let seed = p.kcpSeed, !seed.isEmpty {
            q.append("seed=\(seed)")
        }
        if p.network == "quic" {
            q.append("quicSecurity=\(p.quicSecurity ?? "none")")
            if let key = p.quicKey, !key.isEmpty { q.append("key=\(key)") }
        }
        if let sni = p.sni, !sni.isEmpty { q.append("sni=\(enc(sni))") }
        if let fp = p.fingerprint, !fp.isEmpty { q.append("fp=\(fp)") }
        if let flow = p.flow, !flow.isEmpty { q.append("flow=\(flow)") }
        if let pbk = p.pbk, !pbk.isEmpty { q.append("pbk=\(pbk)") }
        if let sid = p.sid, !sid.isEmpty { q.append("sid=\(sid)") }
        if let spx = p.spiderX, !spx.isEmpty { q.append("spx=\(spx)") }
        if let alpn = p.alpn, !alpn.isEmpty { q.append("alpn=\(alpn)") }
        return q.isEmpty ? "" : "?" + q.joined(separator: "&")
    }

    // MARK: - VMess

    private static func vmessURL(_ p: ShadowsocksProfile) -> String? {
        guard let uuid = p.password, !uuid.isEmpty else { return nil }
        let json: [String: String] = [
            "v": "2",
            "ps": p.name,
            "add": p.server,
            "port": String(p.port),
            "id": uuid,
            "aid": "0",
            "net": p.network ?? "tcp",
            "type": p.type ?? "none",
            "host": p.wsHost ?? "",
            "path": p.wsPath ?? "",
            "tls": (p.security == "tls") ? "tls" : ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []),
              let jsonStr = String(data: data, encoding: .utf8) else { return nil }
        return "vmess://" + base64URL(jsonStr)
    }

    // MARK: - Shadowsocks (SIP002)

    private static func shadowsocksURL(_ p: ShadowsocksProfile) -> String? {
        guard let method = p.method, !method.isEmpty,
              let password = p.password, !password.isEmpty else { return nil }
        let userInfo = base64URL("\(method):\(password)")
        return "ss://\(userInfo)@\(hostPort(p))#\(enc(p.name))"
    }

    // MARK: - Hysteria2

    private static func hysteria2URL(_ p: ShadowsocksProfile) -> String? {
        guard let password = p.password, !password.isEmpty else { return nil }
        var q: [String] = []
        if let sni = p.sni, !sni.isEmpty { q.append("sni=\(enc(sni))") }
        if p.allowInsecure == true { q.append("insecure=1") }
        if let obfs = p.obfs, !obfs.isEmpty, obfs != "none" {
            q.append("obfs=\(obfs)")
            if let pass = p.obfsPassword, !pass.isEmpty { q.append("obfs-password=\(enc(pass))") }
        }
        if let alpn = p.alpn, !alpn.isEmpty { q.append("alpn=\(alpn)") }
        if let ports = p.hy2Ports, !ports.isEmpty { q.append("mport=\(ports)") }
        let params = q.isEmpty ? "" : "?" + q.joined(separator: "&")
        return "hysteria2://\(enc(password))@\(hostPort(p))\(params)#\(enc(p.name))"
    }

    // MARK: - TUIC

    private static func tuicURL(_ p: ShadowsocksProfile) -> String? {
        guard let uuid = p.password, !uuid.isEmpty else { return nil }
        let userInfo: String
        if let pw = p.tuicPassword, !pw.isEmpty {
            userInfo = "\(uuid):\(enc(pw))"
        } else {
            userInfo = uuid
        }
        var q: [String] = []
        if let sni = p.sni, !sni.isEmpty { q.append("sni=\(enc(sni))") }
        q.append("alpn=\(p.alpn?.isEmpty == false ? p.alpn! : "h3")")
        if let cong = p.tuicCongestion, !cong.isEmpty { q.append("congestion_control=\(cong)") }
        if let udp = p.tuicUDPRelayMode, !udp.isEmpty { q.append("udp_relay_mode=\(udp)") }
        if p.allowInsecure == true { q.append("allow_insecure=1") }
        if let fp = p.fingerprint, !fp.isEmpty { q.append("fp=\(fp)") }
        let params = q.isEmpty ? "" : "?" + q.joined(separator: "&")
        return "tuic://\(userInfo)@\(hostPort(p))\(params)#\(enc(p.name))"
    }

    // MARK: - SOCKS5 / HTTP

    private static func proxyURL(_ p: ShadowsocksProfile, prefix: String) -> String? {
        let credentials: String
        if let user = p.method, !user.isEmpty {
            credentials = "\(enc(user)):\(enc(p.password ?? ""))@"
        } else {
            // Пустой userinfo с '@' — чтобы LinkParser корректно распознал ссылку.
            credentials = "@"
        }
        // HTTP-прокси с TLS экспортируется как https://.
        let scheme = (prefix == "http" && p.security == "tls") ? "https" : prefix
        return "\(scheme)://\(credentials)\(hostPort(p))#\(enc(p.name))"
    }

    // MARK: - Helpers

    private static func hostPort(_ p: ShadowsocksProfile) -> String {
        // IPv6 в квадратных скобках
        if p.server.contains(":") && !p.server.hasPrefix("[") {
            return "[\(p.server)]:\(p.port)"
        }
        return "\(p.server):\(p.port)"
    }

    /// URL-safe Base64 без паддинга (стандарт SIP002 / vmess share links).
    static func base64URL(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        b64 = b64.replacingOccurrences(of: "=", with: "")
        return b64
    }
}