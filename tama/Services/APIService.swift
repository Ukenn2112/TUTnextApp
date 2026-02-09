import Foundation

// MARK: - Legacy APIService Wrapper
// Re-exports Core/Networking/APIService for backward compatibility

@available(*, deprecated, message: "Use Core.Networking.APIService instead")
typealias APIService = Core.Networking.APIService

// MARK: - Auth Error

@available(*, deprecated, message: "Use Core.Errors.AppError instead")
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

// MARK: - API Error

@available(*, deprecated, message: "Use Core.Errors.AppError instead")
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
