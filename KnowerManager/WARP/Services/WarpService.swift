import Foundation
import CryptoKit
import SystemConfiguration

// MARK: - Warp Service Error
enum WarpError: Error, LocalizedError {
    case keyGenerationFailed
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return SettingsManager.shared.t(.warpErrKeyGen)
        case .networkError(let err): return "\(SettingsManager.shared.t(.warpErrNetwork)) \(err.localizedDescription)"
        case .invalidResponse: return SettingsManager.shared.t(.warpErrResponse)
        case .apiError(let msg): return "Cloudflare API: \(msg)"
        }
    }
}

// MARK: - Raw Data
struct RawWarpData {
    let response: WarpResponse
    let privateKey: String
}

// MARK: - Warp Service
class WarpService {
    static let shared = WarpService()
    private let baseURL = URL(string: "https://api.cloudflareclient.com/v0a2485/reg")!
    
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    func createWarpIdentityRaw(proxy: (host: String, port: Int)? = nil) async throws -> RawWarpData {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        let privateKeyBase64 = privateKey.rawRepresentation.base64EncodedString()
        let publicKeyBase64 = publicKey.rawRepresentation.base64EncodedString()
        
        let session: URLSession
        if let proxy = proxy, !proxy.host.isEmpty {
            let config = URLSessionConfiguration.ephemeral
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSEnable: true,
                kCFNetworkProxiesSOCKSPort: proxy.port,
                kCFNetworkProxiesSOCKSProxy: proxy.host
            ]
            config.timeoutIntervalForRequest = 10
            session = URLSession(configuration: config)
        } else {
            session = URLSession.shared
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("okhttp/3.12.1", forHTTPHeaderField: "User-Agent")
        
        let timestamp = isoFormatter.string(from: Date())
        
        let bodyData = RegistrationBody(
            key: publicKeyBase64,
            install_id: UUID().uuidString.lowercased(),
            fcm_token: "",
            tos: timestamp,
            type: "ios",
            locale: "en_US"
        )
        
        request.httpBody = try JSONEncoder().encode(bodyData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WarpError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw WarpError.apiError("HTTP \(httpResponse.statusCode): \(responseBody)")
        }
        
        let decoder = JSONDecoder()
        let warpData = try decoder.decode(WarpResponse.self, from: data)
        
        return RawWarpData(response: warpData, privateKey: privateKeyBase64)
    }
}

// MARK: - Proxy Detector (Fixed)
class ProxyDetector {
    static let shared = ProxyDetector()
    // Список портов для быстрой проверки
    private let commonPorts = [7890, 7891, 1080, 1087, 2334, 2080, 8888, 9050, 10808]
    
    func detect() async -> (host: String, port: String)? {
        // 1. Сначала проверяем системные настройки (мгновенно)
        if let systemProxy = getSystemProxy() {
            return systemProxy
        }
        // 2. Если нет, сканируем порты локально
        return await scanCommonPorts()
    }
    
    private func getSystemProxy() -> (host: String, port: String)? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scopes = settings["__SCOPED__"] as? [String: Any] else { return nil }
        
        for key in scopes.keys {
            if let interface = scopes[key] as? [String: Any] {
                // SOCKS
                if let socksEnabled = interface[kCFNetworkProxiesSOCKSEnable as String] as? Int, socksEnabled == 1,
                   let port = interface[kCFNetworkProxiesSOCKSPort as String] as? Int,
                   let host = interface[kCFNetworkProxiesSOCKSProxy as String] as? String {
                    return (host, String(port))
                }
                // HTTP
                if let httpEnabled = interface[kCFNetworkProxiesHTTPEnable as String] as? Int, httpEnabled == 1,
                   let port = interface[kCFNetworkProxiesHTTPPort as String] as? Int,
                   let host = interface[kCFNetworkProxiesHTTPProxy as String] as? String {
                    return (host, String(port))
                }
            }
        }
        return nil
    }
    
    private func scanCommonPorts() async -> (host: String, port: String)? {
        // Проверяем последовательно, чтобы не спамить потоками
        for port in commonPorts {
            if await canConnectTo(port: port) {
                return ("127.0.0.1", String(port))
            }
        }
        return nil
    }
    
    private func canConnectTo(port: Int) async -> Bool {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPProxy: "127.0.0.1",
        ]
        // Очень короткий таймаут для проверки
        config.timeoutIntervalForRequest = 0.2
        config.timeoutIntervalForResource = 0.2
        let session = URLSession(configuration: config)
        
        guard let url = URL(string: "http://127.0.0.1") else { return false }
        
        do {
            let (_, _) = try await session.data(from: url)
            return true // Успешное соединение или ответ
        } catch {
            let nsError = error as NSError
            // Если "Cannot Connect" -> порт закрыт
            if nsError.domain == NSURLErrorDomain &&
                (nsError.code == NSURLErrorCannotConnectToHost || nsError.code == NSURLErrorNetworkConnectionLost) {
                return false
            }
            // Любая другая ошибка (404, bad gateway и т.д.) означает, что прокси там ЕСТЬ и ответил
            return true
        }
    }
}
