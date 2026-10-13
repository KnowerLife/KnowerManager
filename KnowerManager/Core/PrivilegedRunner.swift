import Foundation
import AppKit

/// Единая точка запуска привилегированных (sudo) команд.
/// Сама запрашивает пароль администратора и умеет запоминать его в Keychain.
///
/// Раньше эта логика жила внутри KnowerManager (обход). Она вынесена отдельно,
/// потому что ей пользуется VPN (установка системного прокси через networksetup).
final class PrivilegedRunner {
    static let shared = PrivilegedRunner()

    private var settings = SettingsManager.shared

    /// Пароль администратора, закэшированный в памяти на время сессии.
    private var cachedPassword: String?

    private init() {}

    /// Сбрасывает сохранённый пароль администратора (память + Keychain).
    func forgetPassword() {
        cachedPassword = nil
        KeychainHelper.shared.delete()
    }

    /// Запускает bash-скрипт с правами администратора, при необходимости спрашивая пароль.
    func runAsAdmin(script: String, completion: @escaping (Bool, String) -> Void) {
        getPassword { password in
            guard let password = password else {
                DispatchQueue.main.async { completion(false, self.settings.t(.passCancelled)) }
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                task.arguments = ["-S", "/bin/bash", "-c", script]

                let inputPipe = Pipe()
                let outputPipe = Pipe()

                task.standardInput = inputPipe
                task.standardOutput = outputPipe
                // stderr объединяем с stdout: так проще гарантированно вычитать оба потока
                // без риска взаимоблокировки, при этом текст ошибок sudo остаётся доступен.
                task.standardError = outputPipe

                do {
                    try task.run()

                    if let passData = "\(password)\n".data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(passData)
                    }
                    inputPipe.fileHandleForWriting.closeFile()

                    // Сначала вычитываем весь вывод, затем дожидаемся завершения процесса.
                    let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    task.waitUntilExit()

                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let errorMsg = output

                    DispatchQueue.main.async {
                        if task.terminationStatus == 0 {
                            completion(true, output)
                        } else {
                            if errorMsg.contains("try again") || errorMsg.contains("incorrect") {
                                self.cachedPassword = nil
                                KeychainHelper.shared.delete()
                                completion(false, self.settings.t(.passIncorrect))
                            } else {
                                completion(false, errorMsg.isEmpty ? output : errorMsg)
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async { completion(false, error.localizedDescription) }
                }
            }
        }
    }

    // MARK: - Поиск пароля

    private func getPassword(completion: @escaping (String?) -> Void) {
        if let mem = cachedPassword { completion(mem); return }

        if let saved = KeychainHelper.shared.read() {
            self.cachedPassword = saved
            completion(saved)
            return
        }

        DispatchQueue.main.async {
            self.showCustomPasswordPrompt(completion: completion)
        }
    }

    // MARK: - Кастомное окно ввода (вместо системного)

    private func showCustomPasswordPrompt(completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = settings.t(.passTitle)
        alert.informativeText = settings.t(.passDesc)
        alert.alertStyle = .informational

        alert.addButton(withTitle: settings.t(.btnOK))
        alert.addButton(withTitle: settings.t(.btnCancel))

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = settings.t(.passPlaceholder)

        let checkbox = NSButton(checkboxWithTitle: settings.t(.passRemember), target: nil, action: nil)
        checkbox.state = .off

        let stack = NSStackView(views: [input, checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.frame = NSRect(x: 0, y: 0, width: 220, height: 50)

        alert.accessoryView = stack
        alert.window.initialFirstResponder = input

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let pass = input.stringValue
            if !pass.isEmpty {
                self.cachedPassword = pass
                if checkbox.state == .on { KeychainHelper.shared.save(pass) }
                completion(pass)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}
