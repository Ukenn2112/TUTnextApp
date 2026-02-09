//
//  MockUser
//  TUTnext
//
//  Data models for the application
//
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
        email: "taro.tut@example.com",
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
