import Foundation

// MARK: - Cookie Service

final class CookieService {
    static let shared = CookieService()
    
    private let cookieStorage = HTTPCookieStorage.shared
    private let defaults = UserDefaults.standard
    private let cookieKey = "savedCookies"
    
    private init() {
        restoreCookies()
    }
    
    // MARK: - Save Cookies
    
    func saveCookies(from response: URLResponse, for urlString: String) {
        guard let httpResponse = response as? HTTPURLResponse,
              let headerFields = httpResponse.allHeaderFields as? [String: String]
        else { return }
        
        let url = response.url ?? URL(string: urlString) ?? URL(string: "https://next.tama.ac.jp")!
        
        let setCookieHeaders = headerFields.filter { $0.key.lowercased() == "set-cookie" }
        
        if !setCookieHeaders.isEmpty {
            setCookieHeaders.forEach { header in
                let cookieString = header.value
                let components = cookieString.components(separatedBy: "=")
                guard components.count >= 2,
                      let cookie = HTTPCookie(properties: [
                          .name: components[0],
                          .value: components.dropFirst().joined(separator: "="),
                          .domain: url.host ?? "",
                          .path: "/",
                          .version: "0",
                      ])
                else { return }
                
                DispatchQueue.main.async {
                    self.cookieStorage.setCookie(cookie)
                    print("🍪 Saved cookie: \(cookie.name)")
                }
            }
            
            DispatchQueue.main.async {
                self.persistCookies()
            }
        }
    }
    
    // MARK: - Add Cookies to Request
    
    func addCookies(to request: URLRequest) -> URLRequest {
        var mutableRequest = request
        
        if let url = request.url,
           let cookies = cookieStorage.cookies(for: url)
        {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (headerField, headerValue) in cookieHeaders {
                mutableRequest.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
        
        return mutableRequest
    }
    
    // MARK: - Clear Cookies
    
    func clearCookies() {
        if let cookies = cookieStorage.cookies {
            cookies.forEach { cookie in
                DispatchQueue.main.async {
                    self.cookieStorage.deleteCookie(cookie)
                }
            }
        }
        DispatchQueue.main.async {
            self.defaults.removeObject(forKey: self.cookieKey)
        }
    }
    
    // MARK: - Persistence
    
    private func persistCookies() {
        guard let cookies = cookieStorage.cookies else { return }
        
        let cookieData = cookies.compactMap { cookie -> [String: Any]? in
            guard let properties = cookie.properties else { return nil }
            var serializedProperties: [String: Any] = [:]
            
            for (key, value) in properties {
                serializedProperties[key.rawValue] = value
            }
            
            return serializedProperties
        }
        
        DispatchQueue.main.async {
            self.defaults.set(cookieData, forKey: self.cookieKey)
        }
    }
    
    private func restoreCookies() {
        guard let cookieData = defaults.array(forKey: cookieKey) as? [[String: Any]] else { return }
        
        for properties in cookieData {
            var cookieProperties: [HTTPCookiePropertyKey: Any] = [:]
            
            for (key, value) in properties {
                cookieProperties[HTTPCookiePropertyKey(key)] = value
            }
            
            if let cookie = HTTPCookie(properties: cookieProperties) {
                DispatchQueue.main.async {
                    self.cookieStorage.setCookie(cookie)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    func hasCookiesForDomain(_ domain: String) -> Bool {
        guard let url = URL(string: domain) else { return false }
        return cookieStorage.cookies(for: url)?.isEmpty == false
    }
    
    func getCookieValue(for name: String, domain: String) -> String? {
        guard let url = URL(string: domain) else { return nil }
        return cookieStorage.cookies(for: url)?.first(where: { $0.name == name })?.value
    }
    
    func isSessionValid() -> Bool {
        hasCookiesForDomain("https://next.tama.ac.jp")
    }
}
