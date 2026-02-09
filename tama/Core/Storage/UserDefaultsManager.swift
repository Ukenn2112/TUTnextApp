import Foundation

// MARK: - UserDefaultsManager

/// Wrapper for UserDefaults with type-safe accessors
@MainActor
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let defaults: UserDefaults
    private let suiteName = "group.com.tutnext.tama"
    
    private init() {
        // Use shared group for extension data sharing
        if let suite = UserDefaults(suiteName: suiteName) {
            self.defaults = suite
        } else {
            self.defaults = UserDefaults.standard
        }
    }
    
    // MARK: - String
    
    func get(key: String) -> String? {
        defaults.string(forKey: key)
    }
    
    func set(value: String, key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Int
    
    func getInt(key: String) -> Int? {
        if defaults.object(forKey: key) == nil {
            return nil
        }
        return defaults.integer(forKey: key)
    }
    
    func set(value: Int, key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Double
    
    func getDouble(key: String) -> Double? {
        if defaults.object(forKey: key) == nil {
            return nil
        }
        return defaults.double(forKey: key)
    }
    
    func set(value: Double, key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Bool
    
    func getBool(key: String) -> Bool {
        defaults.bool(forKey: key)
    }
    
    func set(value: Bool, key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Date
    
    func getDate(key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }
    
    func set(value: Date, key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Array
    
    func getArray<T>(key: String) -> [T]? {
        defaults.array(forKey: key) as? [T]
    }
    
    func set(value: [Any], key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Dictionary
    
    func getDictionary<T>(key: String) -> [String: T]? {
        defaults.dictionary(forKey: key) as? [String: T]
    }
    
    func set(value: [String: Any], key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Codable Support
    
    func set<T: Encodable>(object: T, key: String, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(object)
        defaults.set(data, forKey: key)
    }
    
    func get<T: Decodable>(key: String, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let data = defaults.data(forKey: key) else {
            throw AppError.userDefaultsError(error: NSError(domain: "UserDefaults", code: -1))
        }
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Remove & Clear
    
    func remove(key: String) {
        defaults.removeObject(forKey: key)
    }
    
    func clear() {
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
    
    // MARK: - Subscript Support
    
    subscript<T>(key: String) -> T? {
        get {
            get(key: key)
        }
        set {
            set(value: newValue, forKey: key)
        }
    }
}

// MARK: - Preference Keys

/// Type-safe keys for UserDefaults
struct PreferenceKey<T> {
    let key: String
    
    static func string(_ key: String) -> PreferenceKey<String> {
        PreferenceKey(key: key)
    }
    
    static func int(_ key: String) -> PreferenceKey<Int> {
        PreferenceKey(key: key)
    }
    
    static func bool(_ key: String) -> PreferenceKey<Bool> {
        PreferenceKey(key: key)
    }
    
    static func date(_ key: String) -> PreferenceKey<Date> {
        PreferenceKey(key: key)
    }
}

// MARK: - App Preferences

struct AppPreferences {
    static let manager = UserDefaultsManager.shared
    
    enum Keys {
        static let isLoggedIn = "is_logged_in"
        static let lastSyncDate = "last_sync_date"
        static let selectedLanguage = "selected_language"
        static let notificationsEnabled = "notifications_enabled"
        static let darkModeEnabled = "dark_mode_enabled"
        static let selectedSemester = "selected_semester"
    }
    
    // Authentication state
    static var isLoggedIn: Bool {
        get { manager.getBool(key: Keys.isLoggedIn) }
        set { manager.set(value: newValue, key: Keys.isLoggedIn) }
    }
    
    // Last sync timestamp
    static var lastSyncDate: Date? {
        get { manager.getDate(key: Keys.lastSyncDate) }
        set { manager.set(value: newValue!, key: Keys.lastSyncDate) }
    }
    
    // Selected language code
    static var selectedLanguage: String? {
        get { manager.get(key: Keys.selectedLanguage) }
        set { manager.set(value: newValue!, key: Keys.selectedLanguage) }
    }
    
    // Notifications setting
    static var notificationsEnabled: Bool {
        get { manager.getBool(key: Keys.notificationsEnabled) }
        set { manager.set(value: newValue, key: Keys.notificationsEnabled) }
    }
    
    // Dark mode setting
    static var darkModeEnabled: Bool {
        get { manager.getBool(key: Keys.darkModeEnabled) }
        set { manager.set(value: newValue, key: Keys.darkModeEnabled) }
    }
    
    // Selected semester code
    static var selectedSemester: String? {
        get { manager.get(key: Keys.selectedSemester) }
        set { manager.set(value: newValue!, key: Keys.selectedSemester) }
    }
}
