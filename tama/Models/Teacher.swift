import Foundation

/// 教員情報モデル
struct Teacher: Identifiable, Codable {
    var id = UUID()
    let name: String
    let furigana: String?
    let email: String

    enum CodingKeys: String, CodingKey {
        case name, furigana, email
    }
}

/// 教員一覧APIレスポンスモデル
struct TeacherResponse: Codable {
    let status: Bool
    let data: [Teacher]
}
