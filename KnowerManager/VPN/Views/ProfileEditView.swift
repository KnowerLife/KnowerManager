import SwiftUI

struct ProfileEditView: View {
    @Binding var profile: ShadowsocksProfile?
    @ObservedObject var settings = SettingsManager.shared
    var onSave: (ShadowsocksProfile) -> Void
    
    // --- STATE VARIABLES ---
    @State private var name: String = ""
    @State private var selectedProtocol: ProxyProtocol = .vless
    @State private var server: String = ""
    @State private var port: String = "443"
    @State private var uuidOrPassword: String = ""
    
    // Transport
    @State private var network: String = "tcp" // tcp, ws, grpc
    @State private var grpcServiceName: String = ""
    @State private var grpcMultiMode: Bool = false
    @State private var wsPath: String = "/"
    @State private var wsHost: String = ""
    
    // Security
    @State private var security: String = "reality" // none, tls, reality
    @State private var sni: String = ""
    @State private var allowInsecure: Bool = false
    
    // Reality / Vision
    @State private var flow: String = "" // xtls-rprx-vision
    @State private var pbk: String = ""
    @State private var sid: String = ""
    @State private var fingerprint: String = "chrome"
    @State private var spiderX: String = ""
    
    // KCP / QUIC
    @State private var kcpSeed: String = ""
    @State private var quicSecurity: String = ""
    @State private var quicKey: String = ""
    
    // ALPN (список через запятую)
    @State private var alpn: String = ""
    
    let networks = ["tcp", "ws", "httpupgrade", "splithttp", "h2", "grpc", "kcp", "quic"]
    let securities = ["none", "tls", "reality"]
    let fingerprints = ["chrome", "firefox", "safari", "ios", "randomized"]
    let flows = ["", "xtls-rprx-vision"]
    
    // Транспорт/безопасность настраиваются только для Xray-протоколов
    private var isXrayProtocol: Bool {
        selectedProtocol == .vless || selectedProtocol == .vmess || selectedProtocol == .trojan
    }
    private var isSimpleProxy: Bool {
        selectedProtocol == .socks || selectedProtocol == .http
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            Text(profile == nil ? settings.t(.btnCreateProfile) : settings.t(.editTitle))
                .font(.headline)
                .padding(.top)
            
            Form {
                // 1. MAIN INFO
                Section("General") {
                    TextField(settings.t(.labelName), text: $name)
                    
                    Picker(settings.t(.labelProtocol), selection: $selectedProtocol) {
                        ForEach(ProxyProtocol.allCases, id: \.self) { proto in
                            Text(proto.rawValue.uppercased()).tag(proto)
                        }
                    }
                    
                    TextField(settings.t(.labelServer), text: $server)
                    TextField(settings.t(.labelPort), text: $port)
                    
                    if selectedProtocol == .shadowsocks {
                        TextField(settings.t(.labelUUID), text: $uuidOrPassword) // Password
                        TextField(settings.t(.labelEncryption), text: $security) // Method (aes-256-gcm etc)
                    } else {
                        TextField("UUID", text: $uuidOrPassword)
                        
                        if selectedProtocol == .vless && security == "reality" {
                            Picker(settings.t(.labelFlow), selection: $flow) {
                                Text("Не задано").tag("")
                                Text("xtls-rprx-vision").tag("xtls-rprx-vision")
                            }
                        }
                    }
                }
                
                // 2. TRANSPORT (NETWORK)
                if isXrayProtocol {
                    Section(settings.t(.labelNetwork)) {
                        Picker(settings.t(.labelNetwork), selection: $network) {
                            ForEach(networks, id: \.self) { net in
                                Text(net.uppercased()).tag(net)
                            }
                        }.pickerStyle(.segmented)
                        
                        // gRPC Settings
                        if network == "grpc" {
                            TextField(settings.t(.labelServiceName), text: $grpcServiceName)
                            Toggle(settings.t(.labelMultiMode), isOn: $grpcMultiMode)
                        }
                        
                        // WebSocket / HTTPUpgrade / SplitHTTP / H2 — общие поля Path/Host
                        if ["ws", "httpupgrade", "splithttp", "h2"].contains(network) {
                            TextField(settings.t(.labelPath), text: $wsPath)
                            TextField(settings.t(.labelHost), text: $wsHost)
                        }
                        
                        // KCP / QUIC
                        if network == "kcp" {
                            TextField("Seed", text: $kcpSeed)
                        }
                        if network == "quic" {
                            TextField("QUIC Security", text: $quicSecurity)
                                .help("chacha20-poly1305, aes-128-gcm, none")
                            TextField("QUIC Key", text: $quicKey)
                        }
                    }
                    
                    // 3. SECURITY (TLS / REALITY)
                    Section(settings.t(.labelSecurity)) {
                        Picker(settings.t(.labelSecurity), selection: $security) {
                            ForEach(securities, id: \.self) { sec in
                                Text(sec.uppercased()).tag(sec)
                            }
                        }.pickerStyle(.segmented)
                        
                        // TLS & Reality Common
                        if security != "none" {
                            TextField(settings.t(.labelSNI), text: $sni)
                            Picker(settings.t(.labelFingerprint), selection: $fingerprint) {
                                ForEach(fingerprints, id: \.self) { fp in
                                    Text(fp).tag(fp)
                                }
                            }
                        }
                        
                        // TLS Specific
                        if security == "tls" {
                            Toggle(settings.t(.labelAllowInsecure), isOn: $allowInsecure)
                        }
                        
                        // Reality Specific
                        if security == "reality" {
                            TextField(settings.t(.labelPublicKey), text: $pbk)
                            TextField(settings.t(.labelShortId), text: $sid)
                            TextField(settings.t(.labelSpiderX), text: $spiderX)
                        }
                        
                        // ALPN (список через запятую: h2,http/1.1)
                        if security == "tls" || security == "reality" {
                            TextField("ALPN", text: $alpn)
                                .help("h2,http/1.1 — через запятую, например: h2,http/1.1")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.bottom, 10)
            
            // Кнопки
            HStack {
                Button(settings.t(.btnCancel)) { profile = nil }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(settings.t(.btnSave)) { saveChanges() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(server.isEmpty || !isPortValid)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 380, height: 600) // Увеличили высоту для настроек
        .onAppear { loadValues() }
    }
    
    private var isPortValid: Bool {
        guard let p = Int(port) else { return false }
        return (1...65535).contains(p)
    }
    
    private func loadValues() {
        guard let p = profile else {
            // Новый профиль: ставим дефолты
            name = "New Profile"
            return
        }
        
        name = p.name
        selectedProtocol = p.protocolType
        server = p.server
        port = String(p.port)
        uuidOrPassword = p.password ?? ""
        
        network = p.network ?? "tcp"
        grpcServiceName = p.grpcServiceName ?? ""
        grpcMultiMode = p.grpcMultiMode ?? false
        wsPath = p.wsPath ?? "/"
        wsHost = p.wsHost ?? ""
        
        // Для Shadowsocks шифр хранится в p.method, а не в p.security —
        // иначе поле показывало "none" и перезаписывало реальный cipher.
        if p.protocolType == .shadowsocks {
            security = p.method ?? "aes-256-gcm"
        } else {
            security = p.security ?? "none"
        }
        sni = p.sni ?? ""
        allowInsecure = p.allowInsecure ?? false
        
        pbk = p.pbk ?? ""
        sid = p.sid ?? ""
        fingerprint = p.fingerprint ?? "chrome"
        spiderX = p.spiderX ?? ""
        flow = p.flow ?? ""
        
        kcpSeed = p.kcpSeed ?? ""
        quicSecurity = p.quicSecurity ?? ""
        quicKey = p.quicKey ?? ""
        alpn = p.alpn ?? ""
    }
    
    private func saveChanges() {
        // Если это новый профиль, создаем структуру
        var p = profile ?? ShadowsocksProfile(name: name, protocolType: selectedProtocol)
        
        guard let portInt = Int(port), (1...65535).contains(portInt) else { return }
        
        p.name = name
        p.protocolType = selectedProtocol
        p.server = server
        p.port = portInt
        p.password = uuidOrPassword
        
        if selectedProtocol == .shadowsocks {
            // Для SS метод шифрования пишем в method (в UI он лежит в поле security).
            // Если поле осталось от другого режима — берём дефолт, иначе Xray
            // не запустится с невалидным cipher.
            let cipher = (security.isEmpty || ["none", "tls", "reality"].contains(security)) ? "aes-256-gcm" : security
            p.method = cipher
            p.security = nil
            p.network = "tcp"
            p.sni = nil; p.fingerprint = nil
            p.pbk = nil; p.sid = nil; p.spiderX = nil; p.flow = nil
            p.wsPath = nil; p.wsHost = nil
            p.grpcServiceName = nil; p.grpcMultiMode = nil
            p.allowInsecure = nil
        } else if isSimpleProxy {
            // SOCKS5 / HTTP: сохраняем только адрес, порт и авторизацию.
            p.network = "tcp"
            p.security = nil
            p.sni = nil; p.fingerprint = nil; p.flow = nil
        } else if selectedProtocol == .hysteria2 || selectedProtocol == .tuic {
            // Hysteria2 / TUIC: базовые поля без streamSettings.
            p.network = nil
            p.security = nil
            p.sni = sni.isEmpty ? nil : sni
            p.fingerprint = fingerprint
            p.allowInsecure = allowInsecure
            p.alpn = (selectedProtocol == .tuic) ? "h3" : nil
        } else {
            // VLESS / VMess / Trojan
            p.network = network
            p.security = security
            p.sni = sni
            p.fingerprint = fingerprint
            p.flow = flow
            
            // gRPC
            if network == "grpc" {
                p.grpcServiceName = grpcServiceName
                p.grpcMultiMode = grpcMultiMode
            } else {
                p.grpcServiceName = nil; p.grpcMultiMode = nil
            }
            
            // WS / HTTPUpgrade / SplitHTTP / H2
            if ["ws", "httpupgrade", "splithttp", "h2"].contains(network) {
                p.wsPath = wsPath
                p.wsHost = wsHost
            } else {
                p.wsPath = nil; p.wsHost = nil
            }
            
            // KCP / QUIC
            if network == "kcp" {
                p.kcpSeed = kcpSeed.isEmpty ? nil : kcpSeed
                p.quicSecurity = nil; p.quicKey = nil
            } else if network == "quic" {
                p.quicSecurity = quicSecurity.isEmpty ? "none" : quicSecurity
                p.quicKey = quicKey.isEmpty ? nil : quicKey
                p.kcpSeed = nil
            } else {
                p.kcpSeed = nil; p.quicSecurity = nil; p.quicKey = nil
            }
            p.alpn = alpn.isEmpty ? nil : alpn
            
            // TLS
            if security == "tls" {
                p.allowInsecure = allowInsecure
                p.pbk = nil; p.sid = nil; p.spiderX = nil
            }
            
            // Reality
            if security == "reality" {
                p.pbk = pbk
                p.sid = sid
                p.spiderX = spiderX
                p.allowInsecure = nil
            }
            
            if security == "none" {
                p.sni = nil; p.fingerprint = nil
            }
        }
        
        // Сброс пинга
        p.latency = nil
        
        onSave(p)
        profile = nil
    }
}
