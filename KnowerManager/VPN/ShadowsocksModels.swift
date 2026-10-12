import Foundation

enum ProxyProtocol: String, Codable, CaseIterable {
    case vless = "vless"
    case vmess = "vmess"
    case trojan = "trojan"
    case shadowsocks = "shadowsocks"
}

struct ShadowsocksProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var protocolType: ProxyProtocol = .shadowsocks
    
    var server: String
    var port: Int
    
    // Auth
    var method: String?
    var password: String? // UUID для VLESS/VMess или Пароль для SS
    
    // Favorites
    var isFavorite: Bool? = false
    
    // Вспомогательное свойство
    var isBookmarked: Bool {
        get { isFavorite ?? false }
        set { isFavorite = newValue }
    }
    
    // Transport & Security
    var network: String? = "tcp" // tcp, ws, grpc
    var type: String?            // none, http, kcp...
    var security: String?        // tls, reality, none
    
    // WebSocket
    var wsPath: String?
    var wsHost: String?
    
    // gRPC
    var grpcServiceName: String?
    var grpcMultiMode: Bool?     // <-- НОВОЕ (Multi Mode)
    
    // TLS / Reality Settings
    var sni: String?             // Server Name Indication
    var allowInsecure: Bool?     // <-- НОВОЕ (Allow Insecure)
    
    // Reality Specific
    var pbk: String?             // Public Key (Reality)
    var fingerprint: String?     // uTLS (chrome, firefox, etc.)
    var flow: String?            // xtls-rprx-vision
    var sid: String?             // Short ID (Reality)
    var spiderX: String?         // <-- НОВОЕ (SpiderX)
    
    // Diagnostics
    var latency: Int? = nil
    
    var pingColor: String {
        guard let lat = latency else { return "gray" }
        if lat < 150 { return "green" }
        if lat < 300 { return "orange" }
        return "red"
    }
    
    // --- INIT ДЛЯ РУЧНОГО СОЗДАНИЯ ---
    // Это нужно, чтобы создавать пустой профиль через ProfileEditView
    init(name: String, protocolType: ProxyProtocol) {
        self.name = name
        self.protocolType = protocolType
        self.server = ""
        self.port = 443
        self.network = "tcp"
        self.security = "none"
    }
    
    // --- УСТОЙЧИВОЕ ДЕКОДИРОВАНИЕ ---
    // Синтезированный Codable падает, если в сохранённом JSON нет
    // необязательного (с точки зрения типа) ключа. Читаем терпимо к
    // расхождениям схемы, чтобы добавление новых полей не теряло профили.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        protocolType = try c.decodeIfPresent(ProxyProtocol.self, forKey: .protocolType) ?? .shadowsocks
        server = try c.decodeIfPresent(String.self, forKey: .server) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 443
        method = try c.decodeIfPresent(String.self, forKey: .method)
        password = try c.decodeIfPresent(String.self, forKey: .password)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        network = try c.decodeIfPresent(String.self, forKey: .network) ?? "tcp"
        type = try c.decodeIfPresent(String.self, forKey: .type)
        security = try c.decodeIfPresent(String.self, forKey: .security)
        wsPath = try c.decodeIfPresent(String.self, forKey: .wsPath)
        wsHost = try c.decodeIfPresent(String.self, forKey: .wsHost)
        grpcServiceName = try c.decodeIfPresent(String.self, forKey: .grpcServiceName)
        grpcMultiMode = try c.decodeIfPresent(Bool.self, forKey: .grpcMultiMode)
        sni = try c.decodeIfPresent(String.self, forKey: .sni)
        allowInsecure = try c.decodeIfPresent(Bool.self, forKey: .allowInsecure)
        pbk = try c.decodeIfPresent(String.self, forKey: .pbk)
        fingerprint = try c.decodeIfPresent(String.self, forKey: .fingerprint)
        flow = try c.decodeIfPresent(String.self, forKey: .flow)
        sid = try c.decodeIfPresent(String.self, forKey: .sid)
        spiderX = try c.decodeIfPresent(String.self, forKey: .spiderX)
        latency = try c.decodeIfPresent(Int.self, forKey: .latency)
    }
}
