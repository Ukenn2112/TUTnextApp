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

    // MARK: - 旧データクリーンアップ

    /// UserDefaults に旧データが存在する場合、すべてのデータをクリアする
    func clearLegacyDataIfNeeded() {
        guard !AppDefaults.legacyDataCleared else { return }

        let defaults = UserDefaults.standard

        // 旧データの存在をチェック
        let hasLegacyData = defaults.data(forKey: "currentUser") != nil ||
                           defaults.string(forKey: "deviceToken") != nil

        if hasLegacyData {
            print("【KeychainService】旧データ検出 - すべてのデータをクリアします")
            clearAllData()
        }

        // クリア完了フラグを設定
        AppDefaults.legacyDataCleared = true
    }
    
    /// すべての Keychain データをクリアする
    func clearAllKeychainData() {
        let keysToDelete = [
            "currentUser",
            "deviceToken"
        ]

        for key in keysToDelete {
            delete(forKey: key)
        }

        print("【KeychainService】Keychain データをクリアしました")
    }
    
    /// すべてのアプリデータをクリアする（Keychain + UserDefaults + Cookies）
    private func clearAllData() {
        // Keychain をクリア
        clearAllKeychainData()

        // UserDefaults をクリア
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "currentUser")
        defaults.removeObject(forKey: "deviceToken")
        defaults.removeObject(forKey: "savedCookies")
        defaults.removeObject(forKey: "oauth_state")

        // Cookies をクリア（CookieService に委譲）
        CookieService.shared.clearCookies()

        print("【KeychainService】すべてのユーザーデータをクリアしました")
    }
}
