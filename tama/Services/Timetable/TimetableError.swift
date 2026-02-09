import Foundation

/// 時間割関連のエラー定義
enum TimetableError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case invalidResponse
    case dataParsingFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "ユーザー認証が必要です"
        case .invalidEndpoint:
            return "APIエンドポイントが無効です"
        case .requestCreationFailed:
            return "リクエストデータの作成に失敗しました"
        case .noDataReceived:
            return "データが受信できませんでした"
        case .decodingFailed:
            return "レスポンスのデコードに失敗しました"
        case .invalidResponse:
            return "レスポンスの解析に失敗しました"
        case .dataParsingFailed:
            return "データの解析に失敗しました"
        case .apiError(let message):
            return "APIエラー: \(message)"
        }
    }
}
