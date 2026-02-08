import Foundation
import WebKit

/// Legacy Cookie service wrapper using Core/Storage modules
/// Maintains backward compatibility while migrating to Core modules
final class CookieService {
    static let shared = CookieService()
    
    private let cookieService: CookieServiceProtocol
    
    private init(cookieService: CookieServiceProtocol = CookieService.shared) {
        self.cookieService = cookieService
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

enum CookieKeys {
    static let sessionId = "JSESSIONID"
    static let userId = "userId"
    static let loginState = "loginState"
}
