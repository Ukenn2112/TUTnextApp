import Foundation

/// 授業詳細関連のエラー定義
enum CourseDetailError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case dataParsingFailed
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "ユーザー認証情報がありません"
        case .invalidEndpoint:
            return "無効なAPIエンドポイントです"
        case .requestCreationFailed:
            return "リクエストの作成に失敗しました"
        case .noDataReceived:
            return "データを受信できませんでした"
        case .decodingFailed:
            return "データのデコードに失敗しました"
        case .dataParsingFailed:
            return "データの解析に失敗しました"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .apiError(let message):
            return "APIエラー: \(message)"
        }
    }
}
