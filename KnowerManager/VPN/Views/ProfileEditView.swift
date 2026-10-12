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
    
    let networks = ["tcp", "ws", "grpc"]
    let securities = ["none", "tls", "reality"]
    let fingerprints = ["chrome", "firefox", "safari", "ios", "randomized"]
    let flows = ["", "xtls-rprx-vision"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            Text(profile?.id == nil ? settings.t(.btnCreateProfile) : settings.t(.editTitle))
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
                if selectedProtocol != .shadowsocks {
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
                        
                        // WebSocket Settings
                        if network == "ws" {
                            TextField(settings.t(.labelPath), text: $wsPath)
                            TextField(settings.t(.labelHost), text: $wsHost)
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
                .disabled(server.isEmpty || port.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 380, height: 600) // Увеличили высоту для настроек
        .onAppear { loadValues() }
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
        
        security = p.security ?? "none"
        sni = p.sni ?? ""
        allowInsecure = p.allowInsecure ?? false
        
        pbk = p.pbk ?? ""
        sid = p.sid ?? ""
        fingerprint = p.fingerprint ?? "chrome"
        spiderX = p.spiderX ?? ""
        flow = p.flow ?? ""
    }
    
    private func saveChanges() {
        // Если это новый профиль, создаем структуру
        var p = profile ?? ShadowsocksProfile(name: name, protocolType: selectedProtocol)
        
        guard let portInt = Int(port) else { return }
        
        p.name = name
        p.protocolType = selectedProtocol
        p.server = server
        p.port = portInt
        p.password = uuidOrPassword
        
        if selectedProtocol == .shadowsocks {
            // Для SS method пишем в method, а security не используем
            p.method = security // Используем поле security из UI для метода SS
            p.security = nil
            p.network = "tcp"
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
            
            // WS
            if network == "ws" {
                p.wsPath = wsPath
                p.wsHost = wsHost
            } else {
                p.wsPath = nil; p.wsHost = nil
            }
            
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
