import Foundation

// MARK: - SessionManager Protocol

protocol SessionManagerProtocol {
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    var userId: String? { get set }
    var encryptedPassword: String? { get set }
    var isAuthenticated: Bool { get }
    
    func saveSession(accessToken: String, refreshToken: String?, userId: String, encryptedPassword: String?)
    func clearSession()
    func updateTokens(accessToken: String, refreshToken: String?)
}

// MARK: - SessionManager

/// Manages user session data securely
@MainActor
final class SessionManager: SessionManagerProtocol {
    static let shared = SessionManager()
    
    private let keychain: KeychainManager
    private let defaults: UserDefaultsManager
    
    // Keys for storage
    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userId = "user_id"
        static let encryptedPassword = "encrypted_password"
        static let isAuthenticatedKey = "is_authenticated"
    }
    
    init(keychain: KeychainManager = .shared, defaults: UserDefaultsManager = .shared) {
        self.keychain = keychain
        self.defaults = defaults
    }
    
    var accessToken: String? {
        get { keychain.get(key: Keys.accessToken) }
        set {
            if let value = newValue {
                keychain.set(key: Keys.accessToken, value: value)
            } else {
                keychain.delete(key: Keys.accessToken)
            }
        }
    }
    
    var refreshToken: String? {
        get { keychain.get(key: Keys.refreshToken) }
        set {
            if let value = newValue {
                keychain.set(key: Keys.refreshToken, value: value)
            } else {
                keychain.delete(key: Keys.refreshToken)
            }
        }
    }
    
    var userId: String? {
        get { defaults.get(key: Keys.userId) }
        set {
            if let value = newValue {
                defaults.set(value: value, key: Keys.userId)
            } else {
                defaults.remove(key: Keys.userId)
            }
        }
    }
    
    var encryptedPassword: String? {
        get { keychain.get(key: Keys.encryptedPassword) }
        set {
            if let value = newValue {
                keychain.set(key: Keys.encryptedPassword, value: value)
            } else {
                keychain.delete(key: Keys.encryptedPassword)
            }
        }
    }
    
    var isAuthenticated: Bool {
        accessToken != nil && userId != nil
    }
    
    func saveSession(accessToken: String, refreshToken: String?, userId: String, encryptedPassword: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.encryptedPassword = encryptedPassword
        defaults.set(value: true, key: Keys.isAuthenticatedKey)
    }
    
    func clearSession() {
        accessToken = nil
        refreshToken = nil
        userId = nil
        encryptedPassword = nil
        defaults.remove(key: Keys.isAuthenticatedKey)
    }
    
    func updateTokens(accessToken: String, refreshToken: String?) {
        self.accessToken = accessToken
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
        }
    }
}

// MARK: - Session State

struct SessionState {
    let isAuthenticated: Bool
    let userId: String?
    let accessToken: String?
    
    static let empty = SessionState(isAuthenticated: false, userId: nil, accessToken: nil)
    
    static var current: SessionState {
        SessionState(
            isAuthenticated: SessionManager.shared.isAuthenticated,
            userId: SessionManager.shared.userId,
            accessToken: SessionManager.shared.accessToken
        )
    }
}

// MARK: - Session Observer

protocol SessionObserver: AnyObject {
    func sessionDidChange(_ state: SessionState)
    func sessionDidExpire()
    func sessionDidLogout()
}

extension SessionObserver {
    func sessionDidExpire() {}
    func sessionDidLogout() {}
}

// MARK: - SessionNotificationCenter

final class SessionNotificationCenter {
    static let shared = SessionNotificationCenter()
    
    private var observers = NSHashTable<AnyObject>.weakObjects()
    
    private init() {}
    
    func addObserver(_ observer: SessionObserver) {
        observers.add(observer as AnyObject)
    }
    
    func removeObserver(_ observer: SessionObserver) {
        observers.remove(observer as AnyObject)
    }
    
    func notifySessionChange(_ state: SessionState) {
        for observer in observers.allObjects {
            (observer as? SessionObserver)?.sessionDidChange(state)
        }
    }
    
    func notifySessionExpired() {
        for observer in observers.allObjects {
            (observer as? SessionObserver)?.sessionDidExpire()
        }
    }
    
    func notifySessionLogout() {
        for observer in observers.allObjects {
            (observer as? SessionObserver)?.sessionDidLogout()
        }
    }
}
