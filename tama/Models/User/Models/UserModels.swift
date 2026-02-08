import Foundation

/// User model with full Codable support and validation
public struct User: Codable, Identifiable, Equatable, Validatable {
    public let id: String
    @NonEmpty public var username: String
    @NonEmpty public var fullName: String
    @MinLength(minLength: 8) public var encryptedPassword: String?
    @Positive public var allKeijiMidokCnt: Int?
    public var deviceToken: String?
    public var email: Email?
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
        email: Email? = nil,
        studentId: String? = nil,
        department: String? = nil,
        grade: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self._username = NonEmpty(wrappedValue: username)
        self._fullName = NonEmpty(wrappedValue: fullName)
        self._encryptedPassword = encryptedPassword != nil ? MinLength(minLength: 8, wrappedValue: encryptedPassword!) : nil
        self._allKeijiMidokCnt = allKeijiMidokCnt != nil ? Positive(wrappedValue: allKeijiMidokCnt!) : nil
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
    @NonEmpty public var username: String
    @NonEmpty public var password: String
    
    public init(username: String, password: String) {
        self._username = NonEmpty(wrappedValue: username)
        self._password = NonEmpty(wrappedValue: password)
    }
}

/// User profile update request
public struct UserProfileUpdate: Codable, Validatable {
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
