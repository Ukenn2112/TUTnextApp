import CryptoKit
import Foundation
import SwiftUI

/// Google OAuth認証サービス
@MainActor
final class GoogleOAuthService: ObservableObject {
    static let shared = GoogleOAuthService()

    @Published var isAuthorized = false
    @Published var isAuthorizing = false
    @Published var showOAuthWebView = false
    @Published var oauthURL: URL?

    private let clientId: String
    private let redirectUri: String

    /// PKCEパラメータ
    private var codeVerifier: String?
    private var codeChallenge: String?

    private init() {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String else {
            fatalError("CLIENT_ID not found in Info.plist")
        }
        self.clientId = clientId

        guard let reversedClientId = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String else {
            fatalError("REVERSED_CLIENT_ID not found in Info.plist")
        }
        self.redirectUri = "\(reversedClientId):redirect_uri_path"
    }

    // MARK: - OAuth フロー

    /// Google OAuth認証を開始する
    func startOAuth() {
        isAuthorizing = true

        if let url = createAuthURL() {
            self.oauthURL = url
            self.showOAuthWebView = true
        }
    }

    /// OAuth認証をキャンセルする（WebViewが閉じられた時）
    func cancelOAuth() {
        self.isAuthorizing = false
        self.showOAuthWebView = false
        self.oauthURL = nil
    }

    /// 認証コードを処理する
    func handleAuthCode(_ code: String) {
        // WebViewを即座に閉じる
        Task { @MainActor in
            self.showOAuthWebView = false
            self.oauthURL = nil
            NotificationCenter.default.post(name: .googleOAuthWebViewDismissed, object: nil)
        }

        // トークン交換処理を開始
        Task {
            await exchangeCodeForTokens(code)
        }
    }

    // MARK: - サーバー連携

    /// サーバーから認証状態を取得する
    func loadAuthorizationStatus() async {
        guard let user = UserService.shared.getCurrentUser() else {
            await MainActor.run {
                self.isAuthorized = false
            }
            return
        }

        await checkAuthorizationStatus(username: user.username)
    }

    /// サーバーから認証状態をチェックする
    func checkAuthorizationStatus(username: String) async {
        checkGoogleOAuthStatus(username: username) { result in
            Task { @MainActor in
                switch result {
                case .success(let isAuthorized):
                    self.isAuthorized = isAuthorized
                    print("【GoogleOAuth】認証状態: \(isAuthorized)")
                case .failure(let error):
                    print("【GoogleOAuth】認証状態チェックエラー: \(error.localizedDescription)")
                    self.isAuthorized = false
                }
            }
        }
    }

    /// 認証状態をクリアする
    func clearAuthorization() {
        Task {
            await clearAuthorizationAsync()
        }
    }

    /// 認証状態を再読み込みする
    func reloadAuthorizationStatus() {
        Task {
            await loadAuthorizationStatus()
        }
    }

    // MARK: - プライベートメソッド

    /// OAuth認証URLを作成する
    private func createAuthURL() -> URL? {
        generatePKCEParameters()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")

        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "oauth_state")

        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/classroom.courses.readonly https://www.googleapis.com/auth/classroom.coursework.me.readonly https://www.googleapis.com/auth/classroom.student-submissions.me.readonly"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        return components?.url
    }

    /// PKCEパラメータを生成する
    private func generatePKCEParameters() {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        codeVerifier = String((0..<128).map { _ in characters.randomElement()! })

        if let verifier = codeVerifier {
            codeChallenge = generateCodeChallenge(from: verifier)
        }
    }

    /// Code challengeを生成する
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .ascii) else { return nil }

        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)

        // Base64URLエンコード（パディング除去）
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// 認証コードをトークンに交換する
    private func exchangeCodeForTokens(_ code: String) async {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            await MainActor.run {
                self.isAuthorizing = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var parameters = [
            "client_id": clientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]

        if let codeVerifier = codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }

        let body = parameters.compactMap { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let accessToken = json["access_token"] as? String
                    let refreshToken = json["refresh_token"] as? String

                    await MainActor.run {
                        self.isAuthorizing = false
                        self.sendTokensToServer(accessToken: accessToken, refreshToken: refreshToken)
                        NotificationCenter.default.post(
                            name: .googleOAuthSuccess,
                            object: nil,
                            userInfo: [:]
                        )
                    }
                }
            } else {
                await MainActor.run {
                    self.isAuthorizing = false
                }
            }
        } catch {
            await MainActor.run {
                self.isAuthorizing = false
            }
            print("【GoogleOAuth】トークン交換エラー: \(error)")
        }
    }

    /// トークンをサーバーに送信する
    private func sendTokensToServer(accessToken: String?, refreshToken: String?) {
        guard let accessToken = accessToken,
              let user = UserService.shared.getCurrentUser() else {
            return
        }

        Task {
            await sendTokensToServerAsync(
                username: user.username,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        }
    }

    /// トークンをサーバーに送信する（非同期）
    private func sendTokensToServerAsync(username: String, accessToken: String, refreshToken: String?) async {
        sendGoogleOAuthTokens(
            username: username,
            accessToken: accessToken,
            refreshToken: refreshToken
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    print("【GoogleOAuth】トークン送信成功: \(response)")
                    self.isAuthorized = true
                    // 認証状態変更通知
                    NotificationCenter.default.post(name: .googleOAuthStatusChanged, object: nil)
                case .failure(let error):
                    print("【GoogleOAuth】トークン送信エラー: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 認証状態をクリアする（非同期）
    private func clearAuthorizationAsync() async {
        guard let user = UserService.shared.getCurrentUser() else { return }

        revokeGoogleOAuth(username: user.username) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    print("【GoogleOAuth】認証取り消し成功: \(response)")
                    self.isAuthorized = false
                    // 認証状態変更通知
                    NotificationCenter.default.post(name: .googleOAuthStatusChanged, object: nil)
                case .failure(let error):
                    print("【GoogleOAuth】認証取り消しエラー: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - APIメソッド

    /// Google OAuth認証状態をチェックする
    private func checkGoogleOAuthStatus(
        username: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let url = URL(string: "https://tama.qaq.tw/oauth/status") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        let requestBody: [String: Any] = ["username": username]

        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(APIError.requestCreationFailed))
            return
        }

        APIService.shared.request(
            request: request,
            logTag: "GoogleOAuth-Status"
        ) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool {
                    DispatchQueue.main.async {
                        completion(.success(status))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Google OAuthトークンをサーバーに送信する
    private func sendGoogleOAuthTokens(
        username: String,
        accessToken: String,
        refreshToken: String?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "https://tama.qaq.tw/oauth/tokens") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var requestBody: [String: Any] = [
            "username": username,
            "access_token": accessToken
        ]

        if let refreshToken = refreshToken {
            requestBody["refresh_token"] = refreshToken
        }

        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(APIError.requestCreationFailed))
            return
        }

        APIService.shared.request(
            request: request,
            logTag: "GoogleOAuth-Tokens"
        ) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool {
                    let message = json["message"] as? String ?? "No message"
                    DispatchQueue.main.async {
                        if status {
                            completion(.success(json))
                        } else {
                            let error = NSError(
                                domain: "GoogleOAuthService",
                                code: 400,
                                userInfo: [NSLocalizedDescriptionKey: message]
                            )
                            completion(.failure(error))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Google OAuth認証を取り消す
    private func revokeGoogleOAuth(
        username: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "https://tama.qaq.tw/oauth/revoke") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        let requestBody: [String: Any] = ["username": username]

        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(APIError.requestCreationFailed))
            return
        }

        APIService.shared.request(
            request: request,
            logTag: "GoogleOAuth-Revoke"
        ) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Bool {
                    let message = json["message"] as? String ?? "No message"
                    DispatchQueue.main.async {
                        if status {
                            completion(.success(json))
                        } else {
                            let error = NSError(
                                domain: "GoogleOAuthService",
                                code: 400,
                                userInfo: [NSLocalizedDescriptionKey: message]
                            )
                            completion(.failure(error))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
