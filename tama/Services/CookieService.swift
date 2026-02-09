import Foundation

// MARK: - Legacy CookieService Wrapper
// Uses Core.Storage.CookieService for implementation

@MainActor
@available(*, deprecated, message: "Use Core.Storage.CookieService instead")
final class CookieService {
    static let shared = CookieService()
    
    private let cookieService: Core.Storage.CookieService
    
    private init() {
        self.cookieService = Core.Storage.CookieService.shared
    }
    
    /// Add cookies to request
    func addCookies(to request: URLRequest) -> URLRequest {
        cookieService.addCookies(to: request)
    }
    
    /// Save cookies from response
    func saveCookies(from response: URLResponse, for url: String) {
        cookieService.saveCookies(from: response, for: url)
    }
    
    /// Clear all cookies
    func clearCookies() {
        cookieService.clearCookies()
    }
    
    /// Get cookies for URL
    func getCookies(for url: String) -> [HTTPCookie]? {
        cookieService.getCookies(for: url)
    }
}

// MARK: - Cookie Keys

@available(*, deprecated, message: "Cookie keys are now in Core.Storage")
enum CookieKeys {
    static let sessionId = "JSESSIONID"
    static let userId = "userId"
    static let loginState = "loginState"
}
