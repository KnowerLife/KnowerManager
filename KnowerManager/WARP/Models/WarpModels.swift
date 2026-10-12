import Foundation

// MARK: - Models for API
struct RegistrationBody: Codable {
    let key: String
    let install_id: String
    let fcm_token: String
    let tos: String
    let type: String
    let locale: String
}

struct WarpResponse: Codable {
    let id: String?
    let account: WarpAccount
    let config: WarpConfig
    let token: String?
}

struct WarpAccount: Codable {
    let id: String
    let license: String
}

struct WarpConfig: Codable {
    let client_id: String
    let peers: [WarpPeer]
    let interface: WarpInterface
}

struct WarpPeer: Codable {
    let public_key: String
    let endpoint: WarpEndpoint
}

struct WarpEndpoint: Codable {
    let v4: String?
    let v6: String?
    let host: String
}

struct WarpInterface: Codable {
    let addresses: WarpAddresses
}

struct WarpAddresses: Codable {
    let v4: String?
    let v6: String?
}

// Вспомогательная модель
struct GeneratedWarpConfig: Equatable {
    let configText: String
    let licenseKey: String
    let accountId: String
}

// Параметры для AmneziaWG
// (ОБНОВЛЕНО: i1 убран, но значения jc/jmin/jmax усилены)
struct AmneziaParams: Codable, Equatable {
    var jc: Int = 120   // Было 4, стало 120
    var jmin: Int = 23  // Было 40, стало 23
    var jmax: Int = 911 // Было 70, стало 911
    var s1: Int = 0     // Было 15, стало 0
    var s2: Int = 0     // Было 2, стало 0
    var h1: Int = 1
    var h2: Int = 2
    var h3: Int = 4     // Значения h3/h4 из примера
    var h4: Int = 3
    // i1 УБРАН
}

// Форматы экспорта
enum ExportFormat: String, CaseIterable, Identifiable {
    case clash = "Clash Meta"
    case amnezia = "AmneziaWG"
    case singbox = "Sing-box"
    case wireguard = "WireGuard"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .clash: return "yaml"
        case .amnezia, .wireguard: return "conf"
        case .singbox: return "json"
        }
    }
}

// Правила маршрутизации
enum RoutingRule: String, CaseIterable, Identifiable {
    case porno = "Porno (XXX)"
    case discord = "Discord"
    case youtube = "YouTube"
    case socials = "Social Networks"
    case torrent = "Torrents"
    case tools = "Tools"
    case music = "Music"
    
    var id: String { rawValue }
    
    var repoKey: String {
        switch self {
        case .porno: return "porno"
        case .discord: return "discord"
        case .youtube: return "youtube"
        case .socials: return "socials"
        case .torrent: return "torrent"
        case .tools: return "tools"
        case .music: return "music"
        }
    }
}

class ConfigGenerator {
    static let shared = ConfigGenerator()
    
    func generate(format: ExportFormat, data: WarpResponse, privateKey: String, amneziaParams: AmneziaParams, selectedRules: Set<RoutingRule>, endpoint: (String, Int)? = nil) -> String {
        
        let publicKey = data.config.peers.first?.public_key ?? ""
        let v4 = data.config.interface.addresses.v4 ?? "172.16.0.2"
        let v6 = data.config.interface.addresses.v6 ?? "fd01:5ca1:ab1e::2"
        let reserved = "196, 164, 99"
        
        let ep = endpoint ?? ("engage.cloudflareclient.com", 2408)
        
        switch format {
        case .clash:
            return generateClash(pk: privateKey, pub: publicKey, v4: v4, v6: v6, res: reserved, params: amneziaParams, rules: selectedRules)
        case .amnezia:
            return generateAmnezia(pk: privateKey, pub: publicKey, v4: v4, v6: v6, ep: ep, params: amneziaParams)
        case .singbox:
            return generateSingBox(pk: privateKey, pub: publicKey, v4: v4, v6: v6, res: reserved, params: amneziaParams)
        case .wireguard:
            return generateStandardWG(pk: privateKey, pub: publicKey, v4: v4, v6: v6, ep: ep)
        }
    }
    
    // MARK: - CLASH META GENERATOR
    private func generateClash(pk: String, pub: String, v4: String, v6: String, res: String, params: AmneziaParams, rules: Set<RoutingRule>) -> String {
        
        let baseUrl = "https://cdn.jsdelivr.net/gh/nellimonix/ClashXRule@release"
        
        // I1 УБРАН ИЗ ШАБЛОНА
        let anchor = """
        warp-common: &warp-common
          type: wireguard
          ip: \(v4)
          ipv6: \(v6)
          private-key: \(pk)
          public-key: \(pub)
          allowed-ips: ['0.0.0.0/0']
          reserved: [\(res)]
          udp: true
          mtu: 1280
          remote-dns-resolve: true
          dns: [1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001]
          amnezia-wg-option:
           jc: \(params.jc)
           jmin: \(params.jmin)
           jmax: \(params.jmax)
           s1: \(params.s1)
           s2: \(params.s2)
           h1: \(params.h1)
           h2: \(params.h2)
           h4: \(params.h4)
           h3: \(params.h3)
        """
        
        var proxiesString = "proxies:\n"
        var proxyNames: [String] = []
        
        let starEndpoints: [(String, String, Int)] = [
            ("188.114.97.1:500", "188.114.97.1", 500),
            ("188.114.97.148:4500", "188.114.97.148", 4500),
            ("162.159.195.1:500", "162.159.195.1", 500),
            ("engage.cloudflareclient.com:4500", "engage.cloudflareclient.com", 4500),
            ("engage.cloudflareclient.com:500", "engage.cloudflareclient.com", 500),
            ("engage.cloudflareclient.com:2408", "engage.cloudflareclient.com", 2408),
            ("188.114.99.224:1002", "188.114.99.224", 1002),
            ("8.34.146.113:968", "8.34.146.113", 968)
        ]
        
        for ep in starEndpoints {
            let name = "[⭐] \(ep.0)"
            proxyNames.append(name)
            proxiesString += """
            - name: "\(name)"
              <<: *warp-common
              server: \(ep.1)
              port: \(ep.2)\n
            """
        }
        
        let ports = [2408, 1701, 4500, 500]
        proxiesString += "\n# Auto-generated ranges\n"
        
        for i in 1...20 {
            let ip = "162.159.192.\(i)"
            for port in ports {
                let name = "\(ip):\(port)"
                proxyNames.append(name)
                proxiesString += """
                - name: "\(name)"
                  <<: *warp-common
                  server: \(ip)
                  port: \(port)\n
                """
            }
        }
        
        var providersString = ""
        if !rules.isEmpty {
            providersString = "rule-providers:\n"
            for rule in rules {
                providersString += """
                  \(rule.repoKey):
                    type: http
                    behavior: domain
                    url: "\(baseUrl)/\(rule.repoKey).txt"
                    path: ./ruleset/\(rule.repoKey).yaml
                    interval: 86400\n
                """
            }
        }
        
        let proxiesListString = proxyNames.map { "    - \"\($0)\"" }.joined(separator: "\n")
        
        let groupsString = """
        proxy-groups:
        - name: Cloudflare
          type: select
          icon: https://www.vectorlogo.zone/logos/cloudflare/cloudflare-icon.svg
          proxies:
        \(proxiesListString)
          url: 'http://speed.cloudflare.com/'
          interval: 300
        """
        
        var rulesString = "rules:\n"
        rulesString += "- PROCESS-NAME,Discord.exe,Cloudflare\n"
        rulesString += "- PROCESS-NAME,Update.exe,Cloudflare\n"
        rulesString += "- PROCESS-NAME,Discord,Cloudflare\n"
        rulesString += "- PROCESS-NAME,Discord Helper,Cloudflare\n"
        
        for rule in rules {
            rulesString += "- RULE-SET,\(rule.repoKey),Cloudflare\n"
        }
        rulesString += "- MATCH,DIRECT"
        
        return [anchor, proxiesString, providersString, groupsString, rulesString].joined(separator: "\n\n")
    }
    
    // MARK: - AMNEZIA WG
    private func generateAmnezia(pk: String, pub: String, v4: String, v6: String, ep: (String, Int), params: AmneziaParams) -> String {
        // I1 УБРАН
        """
        [Interface]
        PrivateKey = \(pk)
        Address = \(v4)/32, \(v6)/128
        DNS = 1.1.1.1, 1.0.0.1
        MTU = 1280
        
        # AmneziaWG Parameters
        Jc = \(params.jc)
        Jmin = \(params.jmin)
        Jmax = \(params.jmax)
        S1 = \(params.s1)
        S2 = \(params.s2)
        H1 = \(params.h1)
        H2 = \(params.h2)
        H3 = \(params.h3)
        H4 = \(params.h4)

        [Peer]
        PublicKey = \(pub)
        AllowedIPs = 0.0.0.0/0, ::/0
        Endpoint = \(ep.0):\(ep.1)
        PersistentKeepalive = 25
        """
    }
    
    // MARK: - SING-BOX
    private func generateSingBox(pk: String, pub: String, v4: String, v6: String, res: String, params: AmneziaParams) -> String {
        """
        {
          "outbounds": [
            {
              "type": "wireguard",
              "tag": "WARP",
              "server": "engage.cloudflareclient.com",
              "server_port": 2408,
              "local_address": [
                "\(v4)/32",
                "\(v6)/128"
              ],
              "private_key": "\(pk)",
              "peer_public_key": "\(pub)",
              "reserved": [196, 164, 99],
              "mtu": 1280,
              "fake_packets": "\(params.jmin)-\(params.jmax)",
              "fake_packets_size": "\(params.s1)-\(params.s2)",
              "fake_packets_delay": "\(params.h1)-\(params.h2)",
              "fake_packets_mode": "m1"
            }
          ]
        }
        """
    }
    
    // MARK: - STANDARD WG
    private func generateStandardWG(pk: String, pub: String, v4: String, v6: String, ep: (String, Int)) -> String {
        """
        [Interface]
        PrivateKey = \(pk)
        Address = \(v4)/32, \(v6)/128
        DNS = 1.1.1.1
        MTU = 1280

        [Peer]
        PublicKey = \(pub)
        AllowedIPs = 0.0.0.0/0
        Endpoint = \(ep.0):\(ep.1)
        """
    }
}
