import Foundation
import Security

// MARK: - KeychainManager

/// Secure storage for sensitive data using iOS Keychain
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "com.tutnext.tama"
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Save a string value to Keychain
    @discardableResult
    func set(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        return set(key: key, data: data)
    }
    
    /// Save data to Keychain
    @discardableResult
    func set(key: String, data: Data) -> Bool {
        // Delete existing item first
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve a string value from Keychain
    func get(key: String) -> String? {
        guard let data = getData(key: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Retrieve data from Keychain
    func getData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
    
    /// Delete an item from Keychain
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if an item exists
    func exists(key: String) -> Bool {
        getData(key: key) != nil
    }
    
    /// Clear all Keychain items for this service
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Codable Support
    
    /// Save a Codable object to Keychain
    func set<T: Encodable>(key: String, object: T, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(object)
        guard set(key: key, data: data) else {
            throw AppError.keychainError(status: errSecUnableToSave)
        }
    }
    
    /// Retrieve a Codable object from Keychain
    func get<T: Decodable>(key: String, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let data = getData(key: key) else {
            throw AppError.keychainError(status: errSecItemNotFound)
        }
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - KeychainError

extension KeychainManager {
    enum KeychainError: Error {
        case unableToSave
        case unableToLoad
        case itemNotFound
        case unexpectedStatus(OSStatus)
    }
}
