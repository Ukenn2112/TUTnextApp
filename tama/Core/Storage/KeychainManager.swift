import Foundation
import Security

// MARK: - Keychain Manager

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "com.tama.tutnext"
    
    private init() {}
    
    // MARK: - String Operations
    
    func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        setData(data, forKey: key)
    }
    
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteValue(forKey key: String) {
        deleteData(forKey: key)
    }
    
    // MARK: - Data Operations
    
    func setData(_ data: Data, forKey key: String) {
        // Delete existing item first
        deleteData(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain set error: \(status)")
        }
    }
    
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    func deleteData(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Codable Operations
    
    func setCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        setData(data, forKey: key)
    }
    
    func getCodable<T: Decodable>(forKey key: String) throws -> T? {
        guard let data = getData(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain Keys

enum KeychainKey {
    static let accessToken = "accessToken"
    static let refreshToken = "refreshToken"
    static let userCredentials = "userCredentials"
    static let deviceToken = "deviceToken"
}
