import Foundation

/// Cookie管理サービス
final class CookieService {
    static let shared = CookieService()

    private let cookieStorage = HTTPCookieStorage.shared

    private init() {}

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
}
