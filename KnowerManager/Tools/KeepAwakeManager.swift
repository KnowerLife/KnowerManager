import Foundation

final class KeepAwakeManager {
    static let shared = KeepAwakeManager()
    private var isRunning = false
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        // Запускаем caffeinate в фоне (без ограничения времени)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-d", "-i", "-m", "-s"]
        do {
            try task.run()
            isRunning = true
        } catch {
            isRunning = false
        }
    }
    
    func stop() {
        guard isRunning else {
            // Попробуем убить все caffeinate
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            kill.arguments = ["caffeinate"]
            _ = try? kill.run()
            kill.waitUntilExit()
            isRunning = false
            return
        }
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["caffeinate"]
        do {
            try kill.run()
            kill.waitUntilExit()
        } catch {}
        isRunning = false
    }
    
    func isActive() -> Bool {
        return isRunning
    }
}
