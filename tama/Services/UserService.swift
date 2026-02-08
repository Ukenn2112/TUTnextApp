import Foundation

/// Legacy User service wrapper using Core/Auth modules
/// Maintains backward compatibility while migrating to Core modules
final class UserService {
    static let shared = UserService()
    
    private let userService: UserServiceProtocol
    private let defaults: UserDefaultsManager
    
    private init(
        userService: UserServiceProtocol = UserService.shared,
        defaults: UserDefaultsManager = .shared
    ) {
        self.userService = userService
        self.defaults = defaults
    }
    
    /// Save user data
    func saveUser(_ user: User, completion: (() -> Void)? = nil) {
        userService.currentUser = UserMapper.mapToCore(user)
        completion?()
    }
    
    /// Get current user
    func getCurrentUser() -> User? {
        guard let coreUser = userService.currentUser else { return nil }
        return UserMapper.mapFromCore(coreUser)
    }
    
    /// Clear current user
    func clearCurrentUser() {
        userService.clearCurrentUser()
    }
    
    /// Save device token
    func saveDeviceToken(_ token: String) {
        defaults.set(value: token, key: "deviceToken")
    }
    
    /// Get device token
    func getDeviceToken() -> String? {
        defaults.get(key: "deviceToken")
    }
    
    /// Clear device token
    func clearDeviceToken() {
        defaults.remove(key: "deviceToken")
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
}

// MARK: - User Model

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

enum UserMapper {
    static func mapToCore(_ legacy: User) -> Core.User {
        Core.User(
            userId: legacy.id,
            studentId: nil,
            name: legacy.fullName,
            email: nil,
            department: nil,
            grade: nil
        )
    }
    
    static func mapFromCore(_ core: Core.User) -> User {
        User(
            id: core.userId,
            username: core.userId,
            fullName: core.name ?? "",
            encryptedPassword: nil,
            allKeijiMidokCnt: 0
        )
    }
}
