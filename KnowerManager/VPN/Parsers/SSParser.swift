import Foundation

class SSParser {
    static let shared = SSParser()
    
    // Разрешенные символы для метода шифрования
    private let allowedCipherCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
    
    func parse(link: String) -> ShadowsocksProfile? {
        // 1. Предварительная очистка
        let cleanLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanLink.hasPrefix("ss://") else { return nil }
        
        // Убираем префикс (только ведущий — replacingOccurrences удалял бы все вхождения)
        var content = String(cleanLink.dropFirst("ss://".count))
        
        // 2. Отделяем тег (#Name)
        var name = "Shadowsocks Server"
        if let hashIndex = content.firstIndex(of: "#") {
            let tagPart = String(content[content.index(after: hashIndex)...])
            name = tagPart.removingPercentEncoding ?? tagPart
            name = name.components(separatedBy: .controlCharacters).joined() // Чистим от мусора
            content = String(content[..<hashIndex])
        }
        
        // (не логируем содержимое: там могут быть логин/пароль)
        
        // 3. СТРАТЕГИЯ 1: SIP002 (userInfo@host:port)
        if let atIndex = content.lastIndex(of: "@") {
            let userInfoPart = String(content[..<atIndex])
            let hostPart = String(content[content.index(after: atIndex)...])
            
            let cleanUserInfo = userInfoPart.removingPercentEncoding ?? userInfoPart
            let decodedUserInfo = base64Decode(cleanUserInfo) ?? cleanUserInfo
            
            if let profile = extractProfile(userInfo: decodedUserInfo, hostPart: hostPart, name: name) {
                return profile
            }
        }
        
        // 4. СТРАТЕГИЯ 2: Legacy (Вся строка в Base64)
        let cleanBase64 = content.removingPercentEncoding ?? content
        
        if let decodedFull = base64Decode(cleanBase64) {
            if let atIndex = decodedFull.lastIndex(of: "@") {
                let userInfo = String(decodedFull[..<atIndex])
                let hostPart = String(decodedFull[decodedFull.index(after: atIndex)...])
                
                if let profile = extractProfile(userInfo: userInfo, hostPart: hostPart, name: name) {
                    return profile
                }
            }
        }
        
        AppLogger.shared.warning("SSParser: unrecognized link format")
        return nil
    }
    
    // --- Логика извлечения (Method:Password@Host:Port) ---
    private func extractProfile(userInfo: String, hostPart: String, name: String) -> ShadowsocksProfile? {
        let parts = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        
        let method = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let password = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !isValidCipher(method) { return nil }
        
        var server = ""
        var port = 0
        parseHostPort(hostPart, server: &server, port: &port)
        
        if server.isEmpty || port == 0 { return nil }
        
        // --- ИСПРАВЛЕНИЕ: Инициализация по частям ---
        var profile = ShadowsocksProfile(name: name, protocolType: .shadowsocks)
        profile.server = server
        profile.port = port
        profile.method = method
        profile.password = password
        
        return profile
    }
    
    private func parseHostPort(_ input: String, server: inout String, port: inout Int) {
        // input.split(separator: "?")[0] трапает, если строка пустая или начинается с "?".
        let cleanInput = String(input.prefix { $0 != "?" && $0 != "/" })
        guard !cleanInput.isEmpty else { return }
        
        if let colonIndex = cleanInput.lastIndex(of: ":") {
            server = String(cleanInput[..<colonIndex])
            server = server.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            
            if let p = Int(String(cleanInput[cleanInput.index(after: colonIndex)...])), (1...65535).contains(p) {
                port = p
            }
        }
    }
    
    private func isValidCipher(_ method: String) -> Bool {
        if method.count > 35 || method.count < 3 { return false }
        return method.rangeOfCharacter(from: allowedCipherCharacters.inverted) == nil
    }
    
    private func base64Decode(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + (4 - remainder), withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
