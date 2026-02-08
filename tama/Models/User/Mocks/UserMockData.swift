import Foundation
import SwiftUI

/// User mock data for previews and testing
public enum MockUser {
    public static let sampleUser = User(
        id: "user-001",
        username: "taro_tut",
        fullName: "東京 太郎",
        encryptedPassword: "encrypted_password_hash",
        allKeijiMidokCnt: 5,
        deviceToken: "sample_device_token_12345",
        email: Email(wrappedValue: "taro.tut@example.com"),
        studentId: "1234567",
        department: "情報システム学科",
        grade: 3
    )
    
    public static let sampleUsers: [User] = [
        sampleUser,
        User(
            id: "user-002",
            username: "hanako_tut",
            fullName: "東京 花子",
            encryptedPassword: "encrypted_password_hash",
            allKeijiMidokCnt: 3,
            studentId: "1234568",
            department: "情報システム学科",
            grade: 2
        ),
        User(
            id: "user-003",
            username: "jiro_tut",
            fullName: "東京 次郎",
            encryptedPassword: "encrypted_password_hash",
            allKeijiMidokCnt: 8,
            studentId: "1234569",
            department: "ビジネス学科",
            grade: 4
        )
    ]
    
    public static let sampleSession = UserSession(
        user: sampleUser,
        token: AuthToken(
            accessToken: "access_token_12345",
            refreshToken: "refresh_token_67890",
            expiresAt: Date().addingTimeInterval(3600)
        )
    )
}

/// Sample JSON fixtures for User models
public enum UserJSONFixtures {
    public static let validUserJSON = """
    {
        "id": "user-001",
        "username": "taro_tut",
        "fullName": "東京 太郎",
        "encryptedPassword": "encrypted_hash_value",
        "allKeijiMidokCnt": 5,
        "deviceToken": "device_token_123",
        "email": "taro.tut@example.com",
        "studentId": "1234567",
        "department": "情報システム学科",
        "grade": 3,
        "createdAt": "2024-04-01T00:00:00+09:00",
        "updatedAt": "2024-04-15T12:30:00+09:00"
    }
    """
    
    public static let validUsersJSON = """
    {
        "users": [
            {
                "id": "user-001",
                "username": "taro_tut",
                "fullName": "東京 太郎"
            },
            {
                "id": "user-002",
                "username": "hanako_tut",
                "fullName": "東京 花子"
            }
        ]
    }
    """
    
    public static let authTokenJSON = """
    {
        "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
        "refreshToken": "refresh_token_value_here",
        "expiresAt": "2024-04-15T13:00:00+09:00"
    }
    """
    
    public static func userJSON(user: User) -> Data? {
        try? JSONEncoder().encode(user)
    }
    
    public static func usersJSON(users: [User]) -> Data? {
        struct UsersWrapper: Encodable {
            let users: [User]
        }
        return try? JSONEncoder().encode(UsersWrapper(users: users))
    }
}
