import Foundation
import Network

/// Гарантирует, что обёрнутый блок выполнится ровно один раз,
/// даже если его конкурентно вызовут несколько потоков.
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        if done {
            lock.unlock()
            return
        }
        done = true
        lock.unlock()
        body()
    }
}

class TCPPing {
    static func ping(host: String, port: Int, completion: @escaping (Int?) -> Void) {
        // Защита от переполнения: UInt16(port) падает (trap) при port < 0 или > 65535,
        // а порт приходит из разбора внешних ссылок без проверки диапазона.
        guard let portValue = UInt16(exactly: port) else {
            completion(nil)
            return
        }
        
        let hostObj = NWEndpoint.Host(host)
        let portObj = NWEndpoint.Port(rawValue: portValue) ?? NWEndpoint.Port(80)
        
        let connection = NWConnection(host: hostObj, port: portObj, using: .tcp)
        let start = Date()
        let once = OnceFlag()
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let duration = Date().timeIntervalSince(start)
                let ms = Int(duration * 1000)
                once.run { completion(ms) }
                // Снимаем обработчик перед отменой — иначе NWConnection удерживает
                // closure, а closure удерживает NWConnection (утечка на каждый пинг).
                connection.stateUpdateHandler = nil
                connection.cancel()
            case .failed(_):
                // При ошибке обязательно сообщаем о неудаче (nil), иначе вызывающая
                // сторона может зависнуть в ожидании completion.
                once.run { completion(nil) }
                connection.stateUpdateHandler = nil
                connection.cancel()
            case .cancelled:
                once.run { completion(nil) }
                connection.stateUpdateHandler = nil
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        // Таймаут 3 секунды
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            once.run { completion(nil) }
            connection.stateUpdateHandler = nil
            connection.cancel()
        }
    }
}
