import Foundation
import WebKit

// MARK: - CookieService Protocol

protocol CookieServiceProtocol {
    func addCookies(to request: URLRequest) -> URLRequest
    func saveCookies(from response: URLResponse, for url: String)
    func clearCookies()
    func getCookies(for url: String) -> [HTTPCookie]?
}

// MARK: - CookieService

/// Manages HTTP cookies for API requests
@MainActor
final class CookieService: CookieServiceProtocol {
    static let shared = CookieService()
    
    private let cookieStorage = HTTPCookieStorage.shared
    private let domain = "next.tama.ac.jp"
    
    private init() {
        // Configure cookie storage
        cookieStorage.cookieAcceptPolicy = .always
    }
    
    func addCookies(to request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        
        guard let url = request.url else {
            return request
        }
        
        // Get cookies for the domain
        if let cookies = cookieStorage.cookies(for: url) {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            if let cookieString = cookieHeader["Cookie"] {
                modifiedRequest.setValue(cookieString, forHTTPHeaderField: "Cookie")
            }
        }
        
        return modifiedRequest
    }
    
    func saveCookies(from response: URLResponse, for url: String) {
        guard let httpResponse = response as? HTTPURLResponse,
              let url = URL(string: url) else {
            return
        }
        
        // Extract and save cookies from all Set-Cookie headers
        if let headerFields = httpResponse.allHeaderFields as? [String: String] {
            let setCookies = headerFields.filter { $0.key.lowercased() == "set-cookie" }
            
            for header in setCookies {
                if let cookie = HTTPCookie.cookies(withResponseHeaderFields: [header.key: header.value], for: url).first {
                    cookieStorage.setCookie(cookie)
                }
            }
        }
    }
    
    func clearCookies() {
        // Clear all cookies for the domain
        if let cookies = cookieStorage.cookies(for: URL(string: "https://\(domain)")!) {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
        
        // Clear all session cookies
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }
    
    func getCookies(for url: String) -> [HTTPCookie]? {
        guard let url = URL(string: url) else {
            return nil
        }
        return cookieStorage.cookies(for: url)
    }
}

// MARK: - Cookie Storage Keys

enum CookieKeys {
    static let sessionId = "JSESSIONID"
    static let userId = "userId"
    static let loginState = "loginState"
}
