import Foundation

/// Cookie管理サービス
final class CookieService {
    static let shared = CookieService()

    private let cookieStorage = HTTPCookieStorage.shared
    private let keychain = KeychainService.shared
    private let cookieKey = "savedCookies"

    private init() {
        // 起動時に保存されたCookieを復元
        restoreCookies()
    }

    // MARK: - パブリックメソッド

    /// レスポンスからCookieを保存する
    func saveCookies(from response: URLResponse, for urlString: String) {
        guard let httpResponse = response as? HTTPURLResponse,
            let headerFields = httpResponse.allHeaderFields as? [String: String]
        else {
            return
        }

        // レスポンスの実際のURLを使用（利用可能な場合）
        guard let url = response.url ?? URL(string: urlString) else { return }

        let setCookieHeaders = headerFields.filter { $0.key.lowercased() == "set-cookie" }

        if !setCookieHeaders.isEmpty {
            setCookieHeaders.forEach { header in
                let cookieString = header.value
                if let cookie = HTTPCookie(properties: [
                    .name: cookieString.components(separatedBy: "=").first ?? "",
                    .value: cookieString.components(separatedBy: "=").dropFirst().joined(
                        separator: "="),
                    .domain: url.host ?? "",
                    .path: "/",
                    .version: "0"
                ]) {
                    DispatchQueue.main.async {
                        self.cookieStorage.setCookie(cookie)
                    }
                }
            }

            // Cookieを永続化
            DispatchQueue.main.async {
                self.persistCookies()
            }
        }
    }

    /// リクエストにCookieを追加する
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

    /// 全てのCookieを削除する
    func clearCookies() {
        if let cookies = cookieStorage.cookies {
            cookies.forEach { cookie in
                DispatchQueue.main.async {
                    self.cookieStorage.deleteCookie(cookie)
                }
            }
        }
        DispatchQueue.main.async {
            self.keychain.delete(forKey: self.cookieKey)
        }
    }

    /// 指定ドメインのCookieが存在するか確認する
    func hasCookiesForDomain(_ domain: String) -> Bool {
        guard let url = URL(string: domain) else { return false }
        return cookieStorage.cookies(for: url)?.isEmpty == false
    }

    /// 指定名のCookie値を取得する
    func getCookieValue(for name: String, domain: String) -> String? {
        guard let url = URL(string: domain) else { return nil }
        return cookieStorage.cookies(for: url)?.first(where: { $0.name == name })?.value
    }

    /// セッションが有効かどうかを確認する
    func isSessionValid() -> Bool {
        return hasCookiesForDomain("https://next.tama.ac.jp")
    }

    // MARK: - プライベートメソッド

    /// Cookieを永続化する
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

        if let data = try? JSONSerialization.data(withJSONObject: cookieData) {
            keychain.save(data, forKey: cookieKey)
        }
    }

    /// 保存されたCookieを復元する
    private func restoreCookies() {
        guard let data = keychain.loadData(forKey: cookieKey),
              let cookieArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }

        for properties in cookieArray {
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
}
