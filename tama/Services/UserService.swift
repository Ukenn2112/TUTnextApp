import Foundation

// MARK: - Legacy UserService Wrapper
// Uses Core.Auth.UserService for implementation

@MainActor
@available(*, deprecated, message: "Use Core.Auth.UserService instead")
final class UserService {
    static let shared = UserService()
    
    private let userService: Core.Auth.UserService
    private let defaults: Core.Storage.UserDefaultsManager
    
    private init() {
        self.userService = Core.Auth.UserService.shared
        self.defaults = Core.Storage.UserDefaultsManager.shared
    }
    
    /// Create user from API response
    func createUser(from userData: [String: Any]) -> User? {
        guard let id = userData["userId"] as? String,
              let username = userData["username"] as? String,
              let fullName = userData["fullName"] as? String else {
            return nil
        }
        
        return User(
            id: id,
            username: username,
            fullName: fullName,
            encryptedPassword: userData["encryptedPassword"] as? String,
            allKeijiMidokCnt: userData["allKeijiMidokCnt"] as? Int ?? 0
        )
    }
    
    /// Save user data
    func saveUser(_ user: User, completion: (() -> Void)? = nil) {
        userService.saveUser(user)
        completion?()
    }
    
    /// Get current user
    func getCurrentUser() -> User? {
        userService.currentUser
    }
    
    /// Clear current user
    func clearCurrentUser() {
        userService.clearCurrentUser()
    }
    
    /// Save device token
    func saveDeviceToken(_ token: String) {
        defaults.set(value: token, forKey: "deviceToken")
    }
    
    /// Get device token
    func getDeviceToken() -> String? {
        defaults.get(forKey: "deviceToken")
    }
    
    /// Clear device token
    func clearDeviceToken() {
        defaults.remove(forKey: "deviceToken")
    }
    
    /// Update unread count
    func updateAllKeijiMidokCnt(keijiCnt: Int, completion: (() -> Void)? = nil) {
        if var user = getCurrentUser() {
            user = User(id: user.id, username: user.username, fullName: user.fullName, encryptedPassword: user.encryptedPassword, allKeijiMidokCnt: keijiCnt)
            saveUser(user) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    /// Save legacy user (for backward compatibility with Views)
    func saveLegacyUser(_ user: User, completion: (() -> Void)? = nil) {
        saveUser(user) {
            completion?()
        }
    }
}

// MARK: - User Model

@available(*, deprecated, message: "Use Core.Auth.User instead")
struct User: Codable {
    let id: String
    let username: String
    let fullName: String
    var encryptedPassword: String?
    var allKeijiMidokCnt: Int
    
    init(
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

// MARK: - User Mapper

@available(*, deprecated, message: "User mapping is now in Core.Auth.UserService")
enum UserMapper {
    static func mapToCore(_ legacy: User) -> Core.Auth.User {
        Core.Auth.User(
            userId: legacy.id,
            studentId: nil,
            name: legacy.fullName,
            email: nil,
            department: nil,
            grade: nil
        )
    }
    
    static func mapFromCore(_ core: Core.Auth.User) -> User {
        User(
            id: core.userId,
            username: core.userId,
            fullName: core.name ?? "",
            encryptedPassword: nil,
            allKeijiMidokCnt: 0
        )
    }
}
