import Foundation

/// リクエストヘッダーを管理するサービス
final class HeaderService {
    static let shared = HeaderService()

    private init() {}

    /// リクエストに共通ヘッダーを追加する
    func addCommonHeaders(to request: URLRequest) -> URLRequest {
        var mutableRequest = request
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableRequest.setValue(
            "UNIPA/1.1.35 CFNetwork/3826.500.62.2.1 Darwin/24.4.0",
            forHTTPHeaderField: "User-Agent"
        )
        return mutableRequest
    }

    /// リクエストに認証ヘッダー（Cookie）を追加する
    func addAuthHeaders(to request: URLRequest) -> URLRequest {
        return CookieService.shared.addCookies(to: request)
    }
}
