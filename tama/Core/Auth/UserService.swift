import Foundation

// MARK: - User Model

struct User: Codable {
    let userId: String
    let studentId: String?
    let name: String?
    let email: String?
    let department: String?
    let grade: String?
    
    enum CodingKeys: String, CodingKey {
        case userId
        case studentId
        case name
        case email
        case department
        case grade
    }
}

// MARK: - UserService Protocol

protocol UserServiceProtocol {
    var currentUser: User? { get }
    func setCurrentUser(_ user: User)
    func clearCurrentUser()
    func updateUser(_ user: User)
}

// MARK: - UserService

/// Manages user data
@MainActor
final class UserService: UserServiceProtocol {
    static let shared = UserService()
    
    private let defaults: UserDefaultsManager
    private let userKey = "current_user"
    
    private init(defaults: UserDefaultsManager = .shared) {
        self.defaults = defaults
    }
    
    private var _currentUser: User?
    
    var currentUser: User? {
        get {
            if let cached = _currentUser {
                return cached
            }
            // Load from storage
            if let data = defaults.getData(key: userKey),
               let user = try? JSONDecoder().decode(User.self, from: data) {
                _currentUser = user
                return user
            }
            return nil
        }
        set {
            _currentUser = newValue
            if let user = newValue,
               let data = try? JSONEncoder().encode(user) {
                defaults.set(key: userKey, data: data)
            } else {
                defaults.remove(key: userKey)
            }
        }
    }
    
    func setCurrentUser(_ user: User) {
        currentUser = user
    }
    
    func clearCurrentUser() {
        _currentUser = nil
        defaults.remove(key: userKey)
    }
    
    func updateUser(_ user: User) {
        currentUser = user
    }
}

// MARK: - User Extensions

extension UserService {
    /// Check if user is logged in
    var isLoggedIn: Bool {
        currentUser != nil
    }
    
    /// Get user name or placeholder
    var displayName: String {
        currentUser?.name ?? "User"
    }
    
    /// Get user ID or empty string
    var userId: String {
        currentUser?.userId ?? ""
    }
    
    /// Save legacy user (for backward compatibility)
    func saveLegacyUser(_ user: LegacyUser, completion: (() -> Void)? = nil) {
        let coreUser = User(
            userId: user.id,
            studentId: nil,
            name: user.fullName,
            email: nil,
            department: nil,
            grade: nil
        )
        currentUser = coreUser
        completion?()
    }
}

// MARK: - Legacy User Model (for backward compatibility)

@available(*, deprecated, message: "Use Core.Auth.User instead")
public struct LegacyUser {
    public let id: String
    public let username: String
    public let fullName: String
    public var encryptedPassword: String?
    public var allKeijiMidokCnt: Int
    
    public init(
        id: String,
        username: String,
        fullName: String,
        encryptedPassword: String? = nil,
        allKeijiMidokCnt: Int = 0
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.encryptedPassword = encryptedPassword
        self.allKeijiMidokCnt = allKeijiMidokCnt
    }
}
