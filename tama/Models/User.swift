import Foundation

struct User: Codable {
    var id: String
    var username: String
    var fullName: String
    var encryptedPassword: String?
} 