import Foundation

/// 部屋変更の情報を保持するモデル
struct RoomChange: Codable {
    let courseName: String
    let newRoom: String
    let expiryDate: Date
}
