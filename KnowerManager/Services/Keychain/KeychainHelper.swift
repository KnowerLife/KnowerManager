import Foundation
import Security

// --- KEYCHAIN HELPER (Для сохранения пароля) ---
final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.knower.manager.root"
    private let account = "root_user"
    private let genericService = "com.knower.manager.generic"
    
    private init() {}
    
    @discardableResult
    func save(_ data: String) -> Bool {
        let value = Data(data.utf8)
        // Удаляем существующий элемент ТОЛЬКО по ключу (service+account).
        // Раньше в запрос на удаление попадал kSecValueData, поэтому удаление
        // срабатывало лишь при совпадении нового и старого пароля, а SecItemAdd
        // возвращал errSecDuplicateItem — пароль молча не обновлялся.
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] as [String: Any]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = value
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
    
    func read() -> String? {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as [String: Any]
        var res: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &res) == errSecSuccess, let data = res as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete() {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
    
    /// Сохраняет произвольный секрет по ключу.
    @discardableResult
    func set(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: genericService, kSecAttrAccount: key] as [String: Any]
        SecItemDelete(query as CFDictionary)
        let addQuery = [kSecClass: kSecClassGenericPassword, kSecAttrService: genericService, kSecAttrAccount: key, kSecValueData: data] as [String: Any]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
    
    /// Читает секрет по ключу.
    func get(_ key: String) -> String? {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: genericService, kSecAttrAccount: key, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as [String: Any]
        var res: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &res) == errSecSuccess, let data = res as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// Удаляет секрет по ключу.
    func remove(_ key: String) {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: genericService, kSecAttrAccount: key] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
}
