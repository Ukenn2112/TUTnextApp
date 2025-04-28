import Foundation

class HeaderService {
    static let shared = HeaderService()

    private init() {}

    // 为请求添加通用头信息
    func addCommonHeaders(to request: URLRequest) -> URLRequest {
        var mutableRequest = request

        // 添加通用头信息
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableRequest.setValue(
            "UNIPA/1.1.35 CFNetwork/3826.500.62.2.1 Darwin/24.4.0", forHTTPHeaderField: "User-Agent"
        )

        return mutableRequest
    }

    // 为请求添加认证头信息
    func addAuthHeaders(to request: URLRequest) -> URLRequest {
        var mutableRequest = request

        // 添加Cookie
        mutableRequest = CookieService.shared.addCookies(to: mutableRequest)

        return mutableRequest
    }
}
