import Foundation

/// APIエラーの定義
enum APIError: Error {
    case invalidURL
    case requestCreationFailed
    case noData
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .requestCreationFailed:
            return "リクエストの作成に失敗しました"
        case .noData:
            return "データがありません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .decodingError(let error):
            return "デコードエラー: \(error.localizedDescription)"
        }
    }
}
