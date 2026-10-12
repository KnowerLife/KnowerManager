import Foundation

class XrayConfigGenerator {
    static let shared = XrayConfigGenerator()
    
    func createConfig(for profile: ShadowsocksProfile, localPort: Int = 10808) -> String {
            let outbound = generateOutbound(profile)
            let routingBlock = generateRouting() // <-- НОВОЕ
            
            return """
            {
              "log": { "loglevel": "warning" },
              "inbounds": [
                {
                  "port": \(localPort),
                  "listen": "127.0.0.1",
                  "protocol": "socks",
                  "settings": { "auth": "noauth", "udp": true },
                  "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
                }
              ],
              "outbounds": [
                \(outbound),
                { "protocol": "freedom", "tag": "direct" },
                { "protocol": "blackhole", "tag": "block" }
              ],
              \(routingBlock)
            }
            """
        }
        
        // --- ГЕНЕРАТОР МАРШРУТИЗАЦИИ (ОБНОВЛЕННЫЙ) ---
        private func generateRouting() -> String {
            let manager = RoutingManager.shared
            
            // 1. GLOBAL MODE
            if manager.mode == .global {
                return """
                "routing": {
                    "domainStrategy": "AsIs",
                    "rules": [
                        { "type": "field", "outboundTag": "proxy", "port": "0-65535" }
                    ]
                }
                """
            }
            
            // 2. DIRECT MODE
            if manager.mode == .direct {
                return """
                "routing": {
                    "domainStrategy": "AsIs",
                    "rules": [
                        { "type": "field", "outboundTag": "direct", "port": "0-65535" }
                    ]
                }
                """
            }
            
            // 3. RULE-BASED MODE
            var rulesJson: [String] = []
            
            // Добавляем пользовательские правила
            for rule in manager.rules where rule.enabled {
                var parts: [String] = []
                
                parts.append("\"type\": \"field\"")
                parts.append("\"outboundTag\": \(jstr(rule.outboundTag))")
                
                if let d = rule.domain, !d.isEmpty {
                    let dStr = d.map { jstr($0) }.joined(separator: ", ")
                    parts.append("\"domain\": [\(dStr)]")
                }
                
                if let i = rule.ip, !i.isEmpty {
                    let iStr = i.map { jstr($0) }.joined(separator: ", ")
                    parts.append("\"ip\": [\(iStr)]")
                }
                
                if let p = rule.protocolType, !p.isEmpty {
                    let pStr = p.map { jstr($0) }.joined(separator: ", ")
                    parts.append("\"protocol\": [\(pStr)]")
                }
                
                if let port = rule.port, !port.isEmpty {
                    parts.append("\"port\": \(jstr(port))")
                }
                
                rulesJson.append("{ \(parts.joined(separator: ", ")) }")
            }
            
            // Финальное правило (Fallback) - все остальное в Proxy
            rulesJson.append("{ \"type\": \"field\", \"outboundTag\": \"proxy\", \"port\": \"0-65535\", \"network\": \"tcp,udp\" }")
            
            return """
            "routing": {
                "domainStrategy": "IPIfNonMatch",
                "rules": [
                    \(rulesJson.joined(separator: ",\n"))
                ]
            }
            """
        }
    
    private func generateOutbound(_ p: ShadowsocksProfile) -> String {
        // --- 1. ОПРЕДЕЛЕНИЕ SNI ---
        var resolvedSNI = ""
        if let s = p.sni, !s.isEmpty { resolvedSNI = s }
        else if let h = p.wsHost, !h.isEmpty { resolvedSNI = h }
        else if !isIPAddress(p.server) { resolvedSNI = p.server }
        
        // --- 2. НАСТРОЙКИ СЕТИ (Transport) ---
        var networkSettings = ""
        let network = p.network ?? "tcp"
        
        if network == "ws" {
            let hostValue = (p.wsHost?.isEmpty == false) ? p.wsHost! : resolvedSNI
            let headersBlock = hostValue.isEmpty ? "\"headers\": {}" : "\"headers\": { \"Host\": \(jstr(hostValue)) }"
            
            networkSettings = """
            "wsSettings": {
                "path": \(jstr(p.wsPath ?? "/")),
                \(headersBlock)
            },
            """
        } else if network == "httpupgrade" {
            let hostValue = (p.wsHost?.isEmpty == false) ? p.wsHost! : resolvedSNI
            let headersBlock = hostValue.isEmpty ? "\"headers\": {}" : "\"headers\": { \"Host\": \(jstr(hostValue)) }"
            networkSettings = """
            "httpupgradeSettings": {
                "path": \(jstr(p.wsPath ?? "/")),
                \(headersBlock)
            },
            """
        } else if network == "splithttp" {
            let hostValue = (p.wsHost?.isEmpty == false) ? p.wsHost! : resolvedSNI
            let headersBlock = hostValue.isEmpty ? "\"headers\": {}" : "\"headers\": { \"Host\": \(jstr(hostValue)) }"
            networkSettings = """
            "splitHttpSettings": {
                "path": \(jstr(p.wsPath ?? "/")),
                \(headersBlock)
            },
            """
        } else if network == "h2" {
            let hostValue = (p.wsHost?.isEmpty == false) ? p.wsHost! : resolvedSNI
            let hostBlock = hostValue.isEmpty ? "\"host\": []" : "\"host\": [\(jstr(hostValue))]"
            networkSettings = """
            "httpSettings": {
                "path": \(jstr(p.wsPath ?? "/")),
                \(hostBlock)
            },
            """
        } else if network == "kcp" {
            let seedJson = (p.kcpSeed?.isEmpty == false) ? "\"seed\": \(jstr(p.kcpSeed!))," : ""
            networkSettings = """
            "kcpSettings": {
                "mtu": 1350,
                "tti": 50,
                "uplinkCapacity": 12,
                "downlinkCapacity": 100,
                "congestion": false,
                "readBufferSize": 1,
                "writeBufferSize": 1,
                \(seedJson)
                "header": { "type": "none" }
            },
            """
        } else if network == "quic" {
            let qsec = p.quicSecurity ?? "none"
            networkSettings = """
            "quicSettings": {
                "security": \(jstr(qsec)),
                "key": \(jstr(p.quicKey ?? "")),
                "header": { "type": "none" }
            },
            """
        } else if network == "grpc" {
            // Используем настройку MultiMode из профиля
            let multiMode = p.grpcMultiMode == true ? "true" : "false"
            networkSettings = """
            "grpcSettings": {
                "serviceName": \(jstr(p.grpcServiceName ?? "")),
                "multiMode": \(multiMode)
            },
            """
        }
        
        // --- 3. НАСТРОЙКИ БЕЗОПАСНОСТИ ---
        let security = p.security ?? "none"
        // Chrome - самый стабильный вариант для обхода блокировок по отпечатку
        let fp = (p.fingerprint == nil || p.fingerprint!.isEmpty) ? "chrome" : p.fingerprint!
        
        func serverNameJson(_ name: String) -> String {
            return name.isEmpty ? "" : "\"serverName\": \(jstr(name)),"
        }

        // ALPN (список через запятую в профиле)
        func alpnJson() -> String {
            guard let a = p.alpn, !a.isEmpty else { return "" }
            let vals = a.split(separator: ",")
                .map { jstr(String($0).trimmingCharacters(in: .whitespaces)) }
                .joined(separator: ", ")
            return "\"alpn\": [\(vals)],"
        }
        
        var securitySettings = ""
        if security == "reality" {
            // Добавлена поддержка SpiderX
            let spx = (p.spiderX == nil || p.spiderX!.isEmpty) ? "/" : p.spiderX!
            
            securitySettings = """
            "realitySettings": {
                "show": false,
                "fingerprint": \(jstr(fp)),
                \(serverNameJson(resolvedSNI))
                "publicKey": \(jstr(p.pbk ?? "")),
                "shortId": \(jstr(p.sid ?? "")),
                "spiderX": \(jstr(spx))
            }
            """
        } else if security == "tls" {
            // Добавлена поддержка AllowInsecure
            let insecure = p.allowInsecure == true ? "true" : "false"
            
            securitySettings = """
            "tlsSettings": {
                \(serverNameJson(resolvedSNI))
                \(alpnJson())
                "fingerprint": \(jstr(fp)),
                "allowInsecure": \(insecure)
            }
            """
        }
        
        // Сборка StreamSettings
        var streamSettings = ""
        if security != "none" {
            streamSettings = """
            , "streamSettings": { "network": \(jstr(network)), "security": \(jstr(security)), \(networkSettings) \(securitySettings) }
            """
        } else {
            streamSettings = """
            , "streamSettings": { "network": \(jstr(network)), "security": "none", \(networkSettings) "dsSettings": {} }
            """
        }

        // --- 4. ПРОТОКОЛ ---
        // Защита от пустого UUID
        let userId = (p.password == nil || p.password!.isEmpty) ? "00000000-0000-0000-0000-000000000000" : p.password!
        
        if p.protocolType == .vless {
            return """
            {
              "protocol": "vless",
              "tag": "proxy",
              "settings": {
                "vnext": [
                  {
                    "address": \(jstr(p.server)),
                    "port": \(p.port),
                    "users": [
                      {
                        "id": \(jstr(userId)),
                        "encryption": "none",
                        "flow": \(jstr(p.flow ?? ""))
                      }
                    ]
                  }
                ]
              }
              \(streamSettings)
            }
            """
        } else if p.protocolType == .vmess {
             return """
             {
               "protocol": "vmess",
               "tag": "proxy",
               "settings": {
                 "vnext": [
                   {
                     "address": \(jstr(p.server)),
                     "port": \(p.port),
                     "users": [
                       { "id": \(jstr(userId)), "alterId": 0, "security": "auto" }
                     ]
                   }
                 ]
               }
               \(streamSettings)
             }
             """
        } else if p.protocolType == .trojan {
             return """
             {
               "protocol": "trojan",
               "tag": "proxy",
               "settings": {
                 "servers": [
                   { "address": \(jstr(p.server)), "port": \(p.port), "password": \(jstr(userId)) }
                 ]
               }
               \(streamSettings)
             }
             """
        } else if p.protocolType == .hysteria2 {
            // Hysteria2 (hy2)
            let sni = resolvedSNI.isEmpty ? p.server : resolvedSNI
            let fp = (p.fingerprint == nil || p.fingerprint!.isEmpty) ? "chrome" : p.fingerprint!
            let insecure = p.allowInsecure == true ? "true" : "false"
            let obfs = p.obfs ?? ""
            let obfsPassword = p.obfsPassword ?? ""
            return """
            {
              "protocol": "hysteria2",
              "tag": "proxy",
              "settings": {
                "address": \(jstr(p.server)),
                "port": \(p.port),
                "password": \(jstr(userId)),
                "obfs": \(jstr(obfs)),
                "obfsPassword": \(jstr(obfsPassword)),
                "tlsSettings": {
                  "serverName": \(jstr(sni)),
                  \(alpnJson2(p))
                  "fingerprint": \(jstr(fp)),
                  "allowInsecure": \(insecure),
                  "omitEmpty": true
                }
              }
            }
            """
        } else if p.protocolType == .tuic {
            // TUIC
            let sni = resolvedSNI.isEmpty ? p.server : resolvedSNI
            let fp = (p.fingerprint == nil || p.fingerprint!.isEmpty) ? "chrome" : p.fingerprint!
            let insecure = p.allowInsecure == true ? "true" : "false"
            let congestion = p.tuicCongestion ?? "bbr"
            let udpMode = p.tuicUDPRelayMode ?? "native"
            return """
            {
              "protocol": "tuic",
              "tag": "proxy",
              "settings": {
                "address": \(jstr(p.server)),
                "port": \(p.port),
                "uuid": \(jstr(userId)),
                "password": \(jstr(p.tuicPassword ?? "")),
                "congestion_control": \(jstr(congestion)),
                "udp_relay_mode": \(jstr(udpMode)),
                "zero_rtt_handshake": false,
                "auth_timeout": "3s",
                "heartbeat_interval": "10s",
                "tlsSettings": {
                  "serverName": \(jstr(sni)),
                  \(alpnJson2(p))
                  "fingerprint": \(jstr(fp)),
                  "allowInsecure": \(insecure),
                  "disableSystemRoot": false
                }
              }
            }
            """
        } else if p.protocolType == .socks {
            let hasAuth = (p.method?.isEmpty == false)
            var serverObj = "{\n      \"address\": \(jstr(p.server)),\n      \"port\": \(p.port)"
            if hasAuth {
                serverObj += ",\n      \"users\": [ { \"user\": \(jstr(p.method!)), \"pass\": \(jstr(p.password ?? "")) } ]"
            }
            serverObj += "\n    }"
            return """
            {
              "protocol": "socks",
              "tag": "proxy",
              "settings": {
                "servers": [
                  \(serverObj)
                ]
              }
            }
            """
        } else if p.protocolType == .http {
            let hasAuth = (p.method?.isEmpty == false)
            var serverObj = "{\n      \"address\": \(jstr(p.server)),\n      \"port\": \(p.port)"
            if hasAuth {
                serverObj += ",\n      \"users\": [ { \"user\": \(jstr(p.method!)), \"pass\": \(jstr(p.password ?? "")) } ]"
            }
            serverObj += "\n    }"
            return """
            {
              "protocol": "http",
              "tag": "proxy",
              "settings": {
                "servers": [
                  \(serverObj)
                ]
              }
            }
            """
        } else {
            // Shadowsocks
            let method = p.method ?? "chacha20-ietf-poly1305"
            var password = p.password ?? ""
            if method.contains("2022") { password = fixBase64(password) }
            
            return """
            {
              "protocol": "shadowsocks",
              "tag": "proxy",
              "settings": {
                "servers": [
                  {
                    "address": \(jstr(p.server)),
                    "port": \(p.port),
                    "method": \(jstr(method)),
                    "password": \(jstr(password)),
                    "uot": true
                  }
                ]
              }
            }
            """
        }
    }

    /// ALPN для hysteria2/tuic (те же поля, что и alpnJson внутри generateOutbound).
    private func alpnJson2(_ p: ShadowsocksProfile) -> String {
        guard let a = p.alpn, !a.isEmpty else { return "" }
        let vals = a.split(separator: ",")
            .map { jstr(String($0).trimmingCharacters(in: .whitespaces)) }
            .joined(separator: ", ")
        return "\"alpn\": [\(vals)],"
    }
    
    // Helpers
    /// Безопасно кодирует строку как JSON-строку (вместе с кавычками).
    private func jstr(_ s: String) -> String {
        var out = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let c where c.value < 0x20:
                out += String(format: "\\u%04x", c.value)
            default:
                out.unicodeScalars.append(ch)
            }
        }
        return out + "\""
    }
    
    private func isIPAddress(_ str: String) -> Bool {
        var sin = sockaddr_in()
        if str.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 { return true }
        var sin6 = sockaddr_in6()
        if str.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 { return true }
        return false
    }
    
    private func fixBase64(_ input: String) -> String {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + (4 - remainder), withPad: "=", startingAt: 0)
        }
        return base64
    }
}
