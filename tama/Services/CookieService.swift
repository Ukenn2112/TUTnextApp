import Foundation

class CookieService {
    static let shared = CookieService()
    
    private let cookieStorage = HTTPCookieStorage.shared
    private let defaults = UserDefaults.standard
    private let cookieKey = "savedCookies"
    
    private init() {
        // 启动时恢复保存的Cookie
        restoreCookies()
    }
    
    // 保存从响应中获取的Cookie
    func saveCookies(from response: URLResponse, for urlString: String) {
        guard let httpResponse = response as? HTTPURLResponse,
              let headerFields = httpResponse.allHeaderFields as? [String: String] else {
            return
        }
        
        // 使用响应的实际URL，如果可用
        let url = response.url ?? URL(string: urlString) ?? URL(string: "https://next.tama.ac.jp")!
        
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        if !cookies.isEmpty {
            cookies.forEach { cookie in
                cookieStorage.setCookie(cookie)
                print("保存されたCookie: \(cookie.name) = \(cookie.value), ドメイン: \(cookie.domain)")
            }
            
            // 持久化存储Cookie
            persistCookies()
        }
    }
    
    // 为请求添加Cookie
    func addCookies(to request: URLRequest) -> URLRequest {
        var mutableRequest = request
        
        if let url = request.url,
           let cookies = cookieStorage.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (headerField, headerValue) in cookieHeaders {
                mutableRequest.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
        
        return mutableRequest
    }
    
    // 清除所有Cookie
    func clearCookies() {
        cookieStorage.cookies?.forEach { cookie in
            cookieStorage.deleteCookie(cookie)
        }
        defaults.removeObject(forKey: cookieKey)
    }
    
    // 持久化存储Cookie
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
        
        defaults.set(cookieData, forKey: cookieKey)
    }
    
    // 恢复保存的Cookie
    private func restoreCookies() {
        guard let cookieData = defaults.array(forKey: cookieKey) as? [[String: Any]] else { return }
        
        for properties in cookieData {
            var cookieProperties: [HTTPCookiePropertyKey: Any] = [:]
            
            for (key, value) in properties {
                cookieProperties[HTTPCookiePropertyKey(key)] = value
            }
            
            if let cookie = HTTPCookie(properties: cookieProperties) {
                cookieStorage.setCookie(cookie)
            }
        }
    }
    
    // 检查Cookie是否有效的方法
    func hasCookiesForDomain(_ domain: String) -> Bool {
        guard let url = URL(string: domain) else { return false }
        return cookieStorage.cookies(for: url)?.isEmpty == false
    }
    
    // 获取特定Cookie的值
    func getCookieValue(for name: String, domain: String) -> String? {
        guard let url = URL(string: domain) else { return nil }
        return cookieStorage.cookies(for: url)?.first(where: { $0.name == name })?.value
    }
    
    // 检查会话是否有效
    func isSessionValid() -> Bool {
        return hasCookiesForDomain("https://next.tama.ac.jp")
    }
} 