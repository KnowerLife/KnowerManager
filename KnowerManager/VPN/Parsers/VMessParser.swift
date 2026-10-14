import Foundation

struct VMessJSON: Codable {
    let v: String?
    let ps: String?   // Имя
    let add: String?  // Адрес
    let port: AnyCodable? // Порт может быть String или Int
    let id: String?   // UUID
    let aid: AnyCodable?
    let net: String?  // tcp / ws
    let type: String?
    let host: String?
    let path: String?
    let tls: String?
}

// Вспомогательная структура, так как в JSON порт бывает и строкой, и числом
struct AnyCodable: Codable {
    var value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            value = x
        } else if let x = try? container.decode(String.self) {
            value = x
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Port"))
        }
    }
    
    func encode(to encoder: Encoder) throws {}
    
    var asInt: Int {
        if let val = value as? Int { return val }
        if let val = value as? String { return Int(val) ?? 443 }
        return 443
    }
}

class VMessParser {
    static let shared = VMessParser()
    
    func parse(link: String) -> ShadowsocksProfile? {
        guard link.hasPrefix("vmess://") else { return nil }
        
        let base64 = link.replacingOccurrences(of: "vmess://", with: "")
        guard let decodedStr = base64Decode(base64),
              let data = decodedStr.data(using: .utf8) else { return nil }
        
        do {
            let config = try JSONDecoder().decode(VMessJSON.self, from: data)
            
            // Очистка полей от невидимых символов
            let cleanAdd = (config.add ?? "").cleanJSON
            let cleanId = (config.id ?? "").cleanJSON
            let cleanHost = (config.host ?? "").cleanJSON
            let cleanPath = (config.path ?? "").cleanJSON
            let cleanName = (config.ps ?? "VMess Server").cleanJSON
            
            // --- ИСПРАВЛЕНИЕ: Инициализация по частям (чтобы избежать Extra arguments) ---
            
            var profile = ShadowsocksProfile(name: cleanName, protocolType: .vmess)
            
            profile.server = cleanAdd
            profile.port = config.port?.asInt ?? 443
            profile.password = cleanId // UUID
            profile.method = "auto"
            
            // Transport
            profile.network = config.net ?? "tcp"
            profile.type = config.type ?? "none"
            
            // Security (в VMess поле tls может содержать "tls" или быть пустым)
            if let tlsVal = config.tls, !tlsVal.isEmpty, tlsVal != "none" {
                profile.security = "tls"
            } else {
                profile.security = "none"
            }
            
            // WebSocket / HTTP
            profile.wsPath = cleanPath
            profile.wsHost = cleanHost
            
            // SNI для VMess часто совпадает с Host, если включен TLS
            if profile.security == "tls" && !cleanHost.isEmpty {
                profile.sni = cleanHost
            }
            
            return profile
            
        } catch {
            AppLogger.shared.error("VMess Parse Error: \(error)")
            return nil
        }
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

// Расширение для очистки
fileprivate extension String {
    var cleanJSON: String {
        return self.components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
