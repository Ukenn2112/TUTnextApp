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
        
        // 複数のSet-Cookieヘッダーを処理
        let setCookieHeaders = headerFields.filter { $0.key.lowercased() == "set-cookie" }
        
        if !setCookieHeaders.isEmpty {
            // 各Set-Cookieヘッダーを個別に処理
            setCookieHeaders.forEach { header in
                let cookieString = header.value
                if let cookie = HTTPCookie(properties: [
                    .name: cookieString.components(separatedBy: "=").first ?? "",
                    .value: cookieString.components(separatedBy: "=").dropFirst().joined(separator: "="),
                    .domain: url.host ?? "",
                    .path: "/",
                    .version: "0"
                ]) {
                    DispatchQueue.main.async {
                        self.cookieStorage.setCookie(cookie)
                        print("保存されたCookie: \(cookie.name) = \(cookie.value), ドメイン: \(cookie.domain)")
                    }
                }
            }
            
            // 持久化存储Cookie
            DispatchQueue.main.async {
                self.persistCookies()
            }
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
        
        DispatchQueue.main.async {
            self.defaults.set(cookieData, forKey: self.cookieKey)
        }
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
                DispatchQueue.main.async {
                    self.cookieStorage.setCookie(cookie)
                }
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