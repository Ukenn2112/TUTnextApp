import Foundation

/// Protocol for local storage operations
public protocol StorageProtocol {
    /// Save encodable object
    func save<T: Encodable>(_ object: T, forKey key: StorageKey)
    
    /// Retrieve decodable object
    func retrieve<T: Decodable>(forKey key: StorageKey) -> T?
    
    /// Remove object by key
    func remove(forKey key: StorageKey)
    
    /// Clear all stored data
    func clearAll()
}

/// Storage keys
public enum StorageKey: String {
    case currentUser
    case userSession
    case timetable
    case busSchedule
    case assignments
    case courseDetails
    case userCredentials
    case appSettings
}

/// Implementation using UserDefaults and FileManager
public final class LocalStorage: StorageProtocol {
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func save<T: Encodable>(_ object: T, forKey key: StorageKey) {
        do {
            let data = try encoder.encode(object)
            
            // Store in UserDefaults for simple types
            userDefaults.set(data, forKey: key.rawValue)
            
        } catch {
            print("Failed to save \(key.rawValue): \(error)")
        }
    }
    
    public func retrieve<T: Decodable>(forKey key: StorageKey) -> T? {
        guard let data = userDefaults.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to retrieve \(key.rawValue): \(error)")
            return nil
        }
    }
    
    public func remove(forKey key: StorageKey) {
        userDefaults.removeObject(forKey: key.rawValue)
    }
    
    public func clearAll() {
        // Remove all known keys
        for key in StorageKey.allCases {
            remove(forKey: key)
        }
    }
}

/// In-memory storage for testing
public final class InMemoryStorage: StorageProtocol {
    private var storage: [StorageKey: Any] = [:]
    
    public init() {}
    
    public func save<T: Encodable>(_ object: T, forKey key: StorageKey) {
        storage[key] = object
    }
    
    public func retrieve<T: Decodable>(forKey key: StorageKey) -> T? {
        return storage[key] as? T
    }
    
    public func remove(forKey key: StorageKey) {
        storage.removeValue(forKey: key)
    }
    
    public func clearAll() {
        storage.removeAll()
    }
}
