import Foundation
import Security

/// Keychain を使用した安全なデータ保存サービス
final class KeychainService {
    static let shared = KeychainService()

    private let service: String

    private init() {
        service = Bundle.main.bundleIdentifier ?? "com.meikenn.tama"
    }

    // MARK: - パブリックメソッド

    /// Data を Keychain に保存する
    @discardableResult
    func save(_ data: Data, forKey key: String) -> Bool {
        // 既存のアイテムを削除してから保存
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// String を Keychain に保存する
    @discardableResult
    func save(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    /// Keychain から Data を読み取る
    func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Keychain から String を読み取る
    func loadString(forKey key: String) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Keychain からアイテムを削除する
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - UserDefaults からの移行

    /// UserDefaults の敏感データを Keychain に移行する
    func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard

        // currentUser の移行
        if let userData = defaults.data(forKey: "currentUser") {
            if loadData(forKey: "currentUser") == nil {
                save(userData, forKey: "currentUser")
            }
            defaults.removeObject(forKey: "currentUser")
        }

        // deviceToken の移行
        if let token = defaults.string(forKey: "deviceToken") {
            if loadString(forKey: "deviceToken") == nil {
                save(token, forKey: "deviceToken")
            }
            defaults.removeObject(forKey: "deviceToken")
        }

        // savedCookies の移行
        if let cookieArray = defaults.array(forKey: "savedCookies") {
            if loadData(forKey: "savedCookies") == nil {
                if let data = try? JSONSerialization.data(withJSONObject: cookieArray) {
                    save(data, forKey: "savedCookies")
                }
            }
            defaults.removeObject(forKey: "savedCookies")
        }

        // 不要な oauth_state を削除
        defaults.removeObject(forKey: "oauth_state")
    }
}
