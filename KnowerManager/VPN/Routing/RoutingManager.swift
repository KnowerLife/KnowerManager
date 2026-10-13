import Foundation
import Combine

// ПЕРЕИМЕНОВАЛИ во избежание конфликтов (Ambiguous error)
enum VPNRoutingMode: String, Codable, CaseIterable, Identifiable {
    case global = "Global"
    case rules = "Rule-Based"
    case direct = "Direct"

    var id: String { rawValue }
}

/// Куда направлять трафик, попавший под правило (Xray outboundTag).
enum RoutingOutbound: String, CaseIterable, Identifiable {
    case proxy = "proxy"
    case direct = "direct"
    case block = "block"

    var id: String { rawValue }
}

/// Одно правило маршрутизации Xray (секция routing.rules).
struct VPNRoutingRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: String = "field"              // Xray: "field"
    var outboundTag: String = "proxy"       // proxy / direct / block
    var domain: [String]?                   // geosite:, domain:, full:, keyword:, regexp:
    var ip: [String]?                       // geoip:, CIDR, IP
    var port: String?                       // "80,443" или "1000-2000"
    var network: String?                    // "tcp", "udp", "tcp,udp"
    var protocolType: [String]?             // http, tls, quic, bittorrent
    var enabled: Bool = true

    /// Есть ли у правила хотя бы одно условие (иначе оно бесполезно).
    var hasConditions: Bool {
        !(domain ?? []).isEmpty
            || !(ip ?? []).isEmpty
            || !(port ?? "").isEmpty
            || !(protocolType ?? []).isEmpty
            || !(network ?? "").isEmpty
    }
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

    // MARK: - CRUD

    /// Создаёт новое пустое правило (не добавляя его в список).
    func makeRule() -> VPNRoutingRule {
        VPNRoutingRule(name: SettingsManager.shared.t(.routingRuleNew),
                       outboundTag: RoutingOutbound.proxy.rawValue)
    }

    func addRule(_ rule: VPNRoutingRule) {
        rules.append(rule)
    }

    /// Обновляет правило по id. Если правила нет — добавляет его.
    func update(_ rule: VPNRoutingRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    func duplicateRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        var copy = rules[index]
        copy.id = UUID()
        copy.name = "\(copy.name) (\(SettingsManager.shared.t(.routingRuleCopy)))"
        rules.insert(copy, at: index + 1)
    }

    func moveRule(from source: IndexSet, to destination: Int) {
        let moved = source.sorted().map { rules[$0] }
        for index in source.sorted(by: >) {
            rules.remove(at: index)
        }
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertAt = min(max(0, destination - removedBeforeDestination), rules.count)
        rules.insert(contentsOf: moved, at: insertAt)
    }

    // MARK: - Defaults

    // Дефолтные правила
    func loadDefaults() {
        let t = { (key: StringKey) in SettingsManager.shared.t(key) }
        rules = [
            // 1. Блокировка рекламы
            VPNRoutingRule(name: t(.ruleBlockAds), outboundTag: RoutingOutbound.block.rawValue,
                           domain: ["geosite:category-ads-all"], enabled: true),

            // 2. Локальные сети и Private IP -> Direct
            VPNRoutingRule(name: t(.ruleBypassLan), outboundTag: RoutingOutbound.direct.rawValue,
                           ip: ["geoip:private"], enabled: true),

            // 3. Apple -> Direct
            VPNRoutingRule(name: t(.ruleBypassApple), outboundTag: RoutingOutbound.direct.rawValue,
                           domain: ["geosite:apple"], enabled: false),

            // 4. BitTorrent -> Direct
            VPNRoutingRule(name: t(.ruleBypassTorrent), outboundTag: RoutingOutbound.direct.rawValue,
                           protocolType: ["bittorrent"], enabled: true),

            // 5. Telegram -> Proxy
            VPNRoutingRule(name: t(.ruleProxyTelegram), outboundTag: RoutingOutbound.proxy.rawValue,
                           ip: ["geoip:telegram"], enabled: true),

            // 6. Google -> Proxy
            VPNRoutingRule(name: t(.ruleProxyGoogle), outboundTag: RoutingOutbound.proxy.rawValue,
                           domain: ["geosite:google"], enabled: true)
        ]
    }

    // MARK: - Persistence

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
