import Foundation

/// ユーザー情報を表すモデル
struct User: Codable, Equatable {
    var id: String
    var username: String
    var fullName: String
    var encryptedPassword: String?
    var allKeijiMidokCnt: Int?
    var deviceToken: String?
}
