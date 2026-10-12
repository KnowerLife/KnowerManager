import Foundation
import Network
import Combine

class PacServer: ObservableObject {
    static let shared = PacServer()
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8080
    
    @Published var isRunning = false
    
    private init() {} // Private init для синглтона
    
    func startServer(bridgeIP: String, socksPort: String) {
        stopServer()
        
        do {
            let params = NWParameters.tcp
            let newListener = try NWListener(using: params, on: port)
            
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("📄 PAC Server started on port \(self.port)")
                    DispatchQueue.main.async { self.isRunning = true }
                case .failed(let error):
                    print("📄 PAC Server failed: \(error)")
                    DispatchQueue.main.async { self.isRunning = false }
                default: break
                }
            }
            
            newListener.newConnectionHandler = { connection in
                self.handleConnection(connection, bridgeIP: bridgeIP, socksPort: socksPort)
            }
            
            newListener.start(queue: .global())
            self.listener = newListener
            
        } catch {
            print("📄 Failed to create PAC listener: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async { self.isRunning = false }
    }
    
    private func handleConnection(_ connection: NWConnection, bridgeIP: String, socksPort: String) {
        connection.start(queue: .global())
        
        // Генерируем контент PAC файла
        let pacContent = """
                function FindProxyForURL(url, host) {
                    return "SOCKS5 \(bridgeIP):\(socksPort); SOCKS \(bridgeIP):\(socksPort); DIRECT";
                }
                """
        
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/x-ns-proxy-autoconfig\r
        Content-Length: \(pacContent.utf8.count)\r
        Connection: close\r
        \r
        \(pacContent)
        """
        
        // Читаем запрос (нам неважно что там, всегда отдаем PAC)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
            // Отправляем ответ
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
