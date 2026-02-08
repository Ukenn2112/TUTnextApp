import Foundation

/// User model with full Codable support and validation
public struct User: Codable, Identifiable, Equatable {
    public let id: String
    public var username: String
    public var fullName: String
    public var encryptedPassword: String?
    public var allKeijiMidokCnt: Int?
    public var deviceToken: String?
    public var email: String?
    public var studentId: String?
    public var department: String?
    public var grade: Int?
    public var createdAt: Date?
    public var updatedAt: Date?
    
    public init(
        id: String,
        username: String,
        fullName: String,
        encryptedPassword: String? = nil,
        allKeijiMidokCnt: Int? = nil,
        deviceToken: String? = nil,
        email: String? = nil,
        studentId: String? = nil,
        department: String? = nil,
        grade: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.encryptedPassword = encryptedPassword
        self.allKeijiMidokCnt = allKeijiMidokCnt
        self.deviceToken = deviceToken
        self.email = email
        self.studentId = studentId
        self.department = department
        self.grade = grade
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

/// User login credentials
public struct UserCredentials: Codable, Validatable {
    public var username: String
    public var password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    public func validate() throws {
        guard !username.isEmpty else {
            throw ValidationError.nonEmpty(field: "username")
        }
        guard !password.isEmpty else {
            throw ValidationError.nonEmpty(field: "password")
        }
    }
}

/// User profile update request
public struct UserProfileUpdate: Codable {
    public var fullName: String?
    public var email: String?
    public var deviceToken: String?
    
    public init(fullName: String? = nil, email: String? = nil, deviceToken: String? = nil) {
        self.fullName = fullName
        self.email = email
        self.deviceToken = deviceToken
    }
}

/// Authentication token response
public struct AuthToken: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date?
    
    public init(accessToken: String, refreshToken: String, expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

/// User session data
public struct UserSession: Codable {
    public let user: User
    public let token: AuthToken
    public let loginTime: Date
    
    public init(user: User, token: AuthToken, loginTime: Date = Date()) {
        self.user = user
        self.token = token
        self.loginTime = loginTime
    }
}
