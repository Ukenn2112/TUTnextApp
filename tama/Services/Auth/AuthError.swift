import Foundation

/// 認証関連のエラー定義
enum AuthError: Error, LocalizedError {
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case invalidResponse
    case loginFailed(String)
    case logoutFailed(String)
    case userDataNotFound

    var errorDescription: String? {
        switch self {
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
        case .loginFailed(let message):
            return message
        case .logoutFailed(let message):
            return message
        case .userDataNotFound:
            return "ユーザーデータが見つかりません"
        }
    }
}
