import Foundation
import SwiftUI
import CryptoKit

@MainActor
class GoogleOAuthService: ObservableObject {
    static let shared = GoogleOAuthService()
    
    @Published var isAuthorized = false
    @Published var isAuthorizing = false
    @Published var showOAuthWebView = false
    @Published var oauthURL: URL?
    
    private let clientId: String
    private let redirectUri: String
    
    // PKCE参数
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    private init() {
        // Info.plistからクライアントIDを取得
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String else {
            fatalError("CLIENT_ID not found in Info.plist")
        }
        self.clientId = clientId
        
        // Info.plistからReversed Client IDを取得
        guard let reversedClientId = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String else {
            fatalError("REVERSED_CLIENT_ID not found in Info.plist")
        }
        self.redirectUri = "\(reversedClientId):redirect_uri_path"
    }
    
    // MARK: - OAuth Flow
    
    /// Google OAuth認証を開始
    func startOAuth() {
        isAuthorizing = true
        
        let authURL = createAuthURL()
        
        if let url = authURL {
            self.oauthURL = url
            self.showOAuthWebView = true
        }
    }
    
    /// OAuth認証を取り消す（WebViewが閉じられた時）
    func cancelOAuth() {
        self.isAuthorizing = false
        self.showOAuthWebView = false
        self.oauthURL = nil
    }
    
    /// OAuth認証URLを作成
    private func createAuthURL() -> URL? {
        // PKCEパラメータを生成
        generatePKCEParameters()
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        
        // 状態パラメータを生成（セキュリティ向上のため）
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
        
        let finalURL = components?.url
        print("OAuth Debug: Generated URL = \(finalURL?.absoluteString ?? "nil")")
        print("OAuth Debug: Redirect URI = \(redirectUri)")
        print("OAuth Debug: Client ID = \(clientId)")
        print("OAuth Debug: Code Challenge = \(codeChallenge ?? "nil")")
        
        return finalURL
    }
    
    /// PKCEパラメータを生成
    private func generatePKCEParameters() {
        // Code verifier生成 (43-128文字のランダム文字列)
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        codeVerifier = String((0..<128).map { _ in characters.randomElement()! })
        
        // Code challenge生成 (code_verifierのSHA256ハッシュをBase64URLエンコード)
        if let verifier = codeVerifier {
            codeChallenge = generateCodeChallenge(from: verifier)
        }
    }
    
    /// Code challengeを生成
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .ascii) else { return nil }
        
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        
        // Base64URLエンコード (パディング除去)
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// 認証コードを処理
    func handleAuthCode(_ code: String) {
        print("OAuth Debug: Handling auth code, closing WebView immediately")
        
        // WebViewを即座に閉じる
        Task { @MainActor in
            self.showOAuthWebView = false
            self.oauthURL = nil
            
            // WebView閉じられた通知を送信
            NotificationCenter.default.post(name: .googleOAuthWebViewDismissed, object: nil)
        }
        
        // トークン交換処理を開始
        Task {
            await exchangeCodeForTokens(code)
        }
    }
    
    /// 認証コードをトークンに交換
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
        
        // PKCEのcode_verifierを追加
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
                        
                        // トークンをサーバーに送信
                        self.sendTokensToServer(accessToken: accessToken, refreshToken: refreshToken)
                        
                        // 成功通知
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
            print("Token exchange error: \(error)")
        }
    }
    
    // MARK: - Server Integration
    
    /// サーバーから認証状態を取得
    func loadAuthorizationStatus() async {
        guard let user = UserService.shared.getCurrentUser() else {
            await MainActor.run {
                self.isAuthorized = false
            }
            return
        }
        
        await checkAuthorizationStatus(username: user.username)
    }
    
    /// サーバーから認証状態をチェック
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
    
    /// トークンをサーバーに送信
    private func sendTokensToServer(accessToken: String?, refreshToken: String?) {
        guard let accessToken = accessToken,
              let user = UserService.shared.getCurrentUser() else {
            print("Missing access token or user information")
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
    
    /// トークンをサーバーに送信（非同期）
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
                    // 认证状态变化通知
                    NotificationCenter.default.post(name: .googleOAuthStatusChanged, object: nil)
                case .failure(let error):
                    print("【GoogleOAuth】トークン送信エラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 認証状態をクリア
    func clearAuthorization() {
        Task {
            await clearAuthorizationAsync()
        }
    }
    
    /// 認証状態をクリア（非同期）
    private func clearAuthorizationAsync() async {
        guard let user = UserService.shared.getCurrentUser() else { return }
        
        revokeGoogleOAuth(username: user.username) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    print("【GoogleOAuth】認証取り消し成功: \(response)")
                    self.isAuthorized = false
                    // 认证状态变化通知
                    NotificationCenter.default.post(name: .googleOAuthStatusChanged, object: nil)
                case .failure(let error):
                    print("【GoogleOAuth】認証取り消しエラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - API Methods
    
    /// Google OAuth認証状態をチェック
    private func checkGoogleOAuthStatus(
        username: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let url = URL(string: "https://tama.qaq.tw/oauth/status") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "username": username
        ]
        
        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(APIError.requestCreationFailed))
            return
        }
        
        APIService.shared.request(
            request: request,
            logTag: "GoogleOAuth-Status"
        ) { data, response, error in
            if let error = error {
                print("【GoogleOAuth】認証状態チェックネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("【GoogleOAuth】認証状態チェック: データなし")
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("【GoogleOAuth】認証状態レスポンス: \(json)")
                    
                    if let status = json["status"] as? Bool {
                        let message = json["message"] as? String ?? "No message"
                        print("【GoogleOAuth】認証状態結果: \(status), メッセージ: \(message)")
                        
                        DispatchQueue.main.async {
                            completion(.success(status))
                        }
                    } else {
                        print("【GoogleOAuth】認証状態チェック: statusフィールドが見つからない")
                        DispatchQueue.main.async {
                            completion(.failure(APIError.invalidResponse))
                        }
                    }
                } else {
                    print("【GoogleOAuth】認証状態チェック: JSON解析失敗")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                print("【GoogleOAuth】認証状態チェックJSON解析エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Google OAuth トークンをサーバーに送信
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
        
        // refresh_tokenが存在する場合のみ追加
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
                print("【GoogleOAuth】トークン送信ネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("【GoogleOAuth】トークン送信: データなし")
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("【GoogleOAuth】トークン送信レスポンス: \(json)")
                    
                    if let status = json["status"] as? Bool {
                        let message = json["message"] as? String ?? "No message"
                        print("【GoogleOAuth】トークン送信結果: \(status), メッセージ: \(message)")
                        
                        DispatchQueue.main.async {
                            if status {
                                // 成功の場合
                                completion(.success(json))
                            } else {
                                // サーバーからエラーレスポンス
                                let error = NSError(
                                    domain: "GoogleOAuthService", 
                                    code: 400, 
                                    userInfo: [NSLocalizedDescriptionKey: message]
                                )
                                completion(.failure(error))
                            }
                        }
                    } else {
                        print("【GoogleOAuth】トークン送信: statusフィールドが見つからない")
                        DispatchQueue.main.async {
                            completion(.failure(APIError.invalidResponse))
                        }
                    }
                } else {
                    print("【GoogleOAuth】トークン送信: JSON解析失敗")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                print("【GoogleOAuth】トークン送信JSON解析エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Google OAuth認証を取り消し
    private func revokeGoogleOAuth(
        username: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "https://tama.qaq.tw/oauth/revoke") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "username": username
        ]
        
        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(APIError.requestCreationFailed))
            return
        }
        
        APIService.shared.request(
            request: request,
            logTag: "GoogleOAuth-Revoke"
        ) { data, response, error in
            if let error = error {
                print("【GoogleOAuth】認証取り消しネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("【GoogleOAuth】認証取り消し: データなし")
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("【GoogleOAuth】認証取り消しレスポンス: \(json)")
                    
                    if let status = json["status"] as? Bool {
                        let message = json["message"] as? String ?? "No message"
                        print("【GoogleOAuth】認証取り消し結果: \(status), メッセージ: \(message)")
                        
                        DispatchQueue.main.async {
                            if status {
                                // 成功の場合
                                completion(.success(json))
                            } else {
                                // サーバーからエラーレスポンス
                                let error = NSError(
                                    domain: "GoogleOAuthService", 
                                    code: 400, 
                                    userInfo: [NSLocalizedDescriptionKey: message]
                                )
                                completion(.failure(error))
                            }
                        }
                    } else {
                        print("【GoogleOAuth】認証取り消し: statusフィールドが見つからない")
                        DispatchQueue.main.async {
                            completion(.failure(APIError.invalidResponse))
                        }
                    }
                } else {
                    print("【GoogleOAuth】認証取り消し: JSON解析失敗")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                print("【GoogleOAuth】認証取り消しJSON解析エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 認証状態を再読み込み
    func reloadAuthorizationStatus() {
        Task {
            await loadAuthorizationStatus()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let googleOAuthSuccess = Notification.Name("GoogleOAuthSuccess")
    static let googleOAuthError = Notification.Name("GoogleOAuthError")
    static let googleOAuthWebViewDismissed = Notification.Name("GoogleOAuthWebViewDismissed")
    static let googleOAuthCallbackReceived = Notification.Name("GoogleOAuthCallbackReceived")
    static let googleOAuthStatusChanged = Notification.Name("GoogleOAuthStatusChanged")
}
