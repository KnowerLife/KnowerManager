import Foundation

// MARK: - Общий парсер ссылок (ручной импорт и подписки)

enum LinkParser {

    /// Разбирает текст со ссылками (подписка/список/буфер обмена) в массив профилей.
    /// Поддерживает: ss://, vmess://, vless://, trojan:// (+ Base64-кодированное тело целиком).
    static func parseLinks(from text: String) -> [ShadowsocksProfile] {
        var cleanText = text
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<BR>", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: " ", with: "\n")

        // Некоторые провайдеры отдают подписку целиком в Base64.
        var textToUse = cleanText
        if !cleanText.contains("://") {
            let trimmed = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = Data(base64Encoded: trimmed),
               let decoded = String(data: data, encoding: .utf8) {
                textToUse = decoded
            }
        }

        var profiles: [ShadowsocksProfile] = []
        for line in textToUse.components(separatedBy: .newlines) {
            let trim = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trim.isEmpty else { continue }

            var profile: ShadowsocksProfile?
            if trim.hasPrefix("ss://") {
                profile = SSParser.shared.parse(link: trim)
            } else if trim.hasPrefix("vmess://") {
                profile = VMessParser.shared.parse(link: trim)
            } else if trim.hasPrefix("vless://") || trim.hasPrefix("trojan://") {
                profile = VLESSParser.shared.parse(link: trim)
            } else if trim.hasPrefix("hysteria2://") || trim.hasPrefix("hy2://") {
                profile = Hysteria2Parser.shared.parse(link: trim)
            } else if trim.hasPrefix("tuic://") {
                profile = TUICParser.shared.parse(link: trim)
            } else if trim.hasPrefix("socks5://") || trim.hasPrefix("socks://") {
                profile = SOCKSProxyParser.shared.parse(link: trim)
            } else if trim.hasPrefix("http://") || trim.hasPrefix("https://") {
                // HTTP(S) proxy-ссылка только если содержит userinfo (user:pass@host:port)
                if trim.contains("@") {
                    profile = HTTPProxyParser.shared.parse(link: trim)
                }
            }

            guard let parsed = profile else { continue }
            profiles.append(parsed)
        }
        return profiles
    }
}