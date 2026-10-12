import Foundation
import Combine

// ПЕРЕИМЕНОВАЛИ во избежание конфликтов (Ambiguous error)
enum VPNRoutingMode: String, Codable, CaseIterable {
    case global = "Global"
    case rules = "Rule-Based"
    case direct = "Direct"
}

struct VPNRoutingRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: String // "field"
    var outboundTag: String // "proxy", "direct", "block"
    var domain: [String]?
    var ip: [String]?
    var port: String?
    var protocolType: [String]? // ["http", "tls", "bittorrent"]
    var enabled: Bool = true
}

class RoutingManager: ObservableObject {
    static let shared = RoutingManager()
    
    @Published var mode: VPNRoutingMode = .rules {
        didSet { save() }
    }
    
    // Стандартные правила
    @Published var rules: [VPNRoutingRule] = [] {
        didSet { save() }
    }
    
    private let storageKey = "KnowerRoutingSettings"
    
    private init() {
        load()
    }
    
    // Дефолтные правила
    func loadDefaults() {
        rules = [
            // 1. Блокировка рекламы
            VPNRoutingRule(name: "Block Ads", type: "field", outboundTag: "block", domain: ["geosite:category-ads-all"], enabled: true),
            
            // 2. Локальные сети и Private IP -> Direct
            VPNRoutingRule(name: "Bypass LAN & Private", type: "field", outboundTag: "direct", ip: ["geoip:private", "geoip:cn"], enabled: true),
            
            // 3. Apple -> Direct
            VPNRoutingRule(name: "Bypass Apple", type: "field", outboundTag: "direct", domain: ["geosite:apple"], enabled: false),
            
            // 4. BitTorrent -> Direct
            VPNRoutingRule(name: "Bypass BitTorrent", type: "field", outboundTag: "direct", protocolType: ["bittorrent"], enabled: true),
            
            // 5. Telegram -> Proxy
            VPNRoutingRule(name: "Proxy Telegram", type: "field", outboundTag: "proxy", ip: ["geoip:telegram"], enabled: true),
            
            // 6. Google -> Proxy
            VPNRoutingRule(name: "Proxy Google", type: "field", outboundTag: "proxy", domain: ["geosite:google"], enabled: true)
        ]
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(mode) {
            UserDefaults.standard.set(data, forKey: "\(storageKey)_mode")
        }
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: "\(storageKey)_rules")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "\(storageKey)_mode"),
           let savedMode = try? JSONDecoder().decode(VPNRoutingMode.self, from: data) {
            self.mode = savedMode
        }
        
        if let data = UserDefaults.standard.data(forKey: "\(storageKey)_rules"),
           let savedRules = try? JSONDecoder().decode([VPNRoutingRule].self, from: data) {
            self.rules = savedRules
        } else {
            loadDefaults()
        }
    }
}
