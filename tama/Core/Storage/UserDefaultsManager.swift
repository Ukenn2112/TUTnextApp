import Foundation

// MARK: - User Defaults Manager

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.tama.tutnext") {
            self.defaults = sharedDefaults
        } else {
            self.defaults = .standard
        }
    }
    
    // MARK: - String Operations
    
    func setString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getString(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }
    
    // MARK: - Bool Operations
    
    func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getBool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }
    
    // MARK: - Int Operations
    
    func setInt(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getInt(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }
    
    // MARK: - Double Operations
    
    func setDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getDouble(forKey key: String) -> Double? {
        let value = defaults.double(forKey: key)
        return defaults.object(forKey: key) != nil ? value : nil
    }
    
    // MARK: - Date Operations
    
    func setDate(_ value: Date, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getDate(forKey key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }
    
    // MARK: - Object Operations
    
    func setObject(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getObject(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }
    
    // MARK: - Codable Operations
    
    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }
    
    func getCodable<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    
    // MARK: - Array Operations
    
    func setArray(_ value: [Any], forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getArray(forKey key: String) -> [Any]? {
        defaults.array(forKey: key)
    }
    
    // MARK: - Dictionary Operations
    
    func setDictionary(_ value: [String: Any], forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    func getDictionary(forKey key: String) -> [String: Any]? {
        defaults.dictionary(forKey: key)
    }
    
    // MARK: - Remove Operations
    
    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
    
    // MARK: - Synchronize
    
    func synchronize() {
        defaults.synchronize()
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
    }
}

// MARK: - User Defaults Keys

enum UserDefaultsKey {
    static let currentUser = "currentUser"
    static let deviceToken = "deviceToken"
    static let languageCode = "languageCode"
    static let themeMode = "themeMode"
    static let lastSyncDate = "lastSyncDate"
    static let notificationEnabled = "notificationEnabled"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

// MARK: - Preference Manager

final class PreferenceManager {
    static let shared = PreferenceManager()
    
    private let defaults: UserDefaultsManager
    
    private init(defaults: UserDefaultsManager = .shared) {
        self.defaults = defaults
    }
    
    // MARK: - Theme
    
    var themeMode: Int {
        get { defaults.getInt(forKey: UserDefaultsKey.themeMode) }
        set { defaults.setInt(newValue, forKey: UserDefaultsKey.themeMode) }
    }
    
    // MARK: - Language
    
    var languageCode: String {
        get { defaults.getString(forKey: UserDefaultsKey.languageCode) ?? "ja" }
        set { defaults.setString(newValue, forKey: UserDefaultsKey.languageCode) }
    }
    
    // MARK: - Notifications
    
    var isNotificationEnabled: Bool {
        get { defaults.getBool(forKey: UserDefaultsKey.notificationEnabled) }
        set { defaults.setBool(newValue, forKey: UserDefaultsKey.notificationEnabled) }
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        get { defaults.getBool(forKey: UserDefaultsKey.hasCompletedOnboarding) }
        set { defaults.setBool(newValue, forKey: UserDefaultsKey.hasCompletedOnboarding) }
    }
    
    // MARK: - Last Sync
    
    var lastSyncDate: Date? {
        get { defaults.getDate(forKey: UserDefaultsKey.lastSyncDate) }
        set { 
            if let date = newValue {
                defaults.setDate(date, forKey: UserDefaultsKey.lastSyncDate)
            } else {
                defaults.removeValue(forKey: UserDefaultsKey.lastSyncDate)
            }
        }
    }
}
