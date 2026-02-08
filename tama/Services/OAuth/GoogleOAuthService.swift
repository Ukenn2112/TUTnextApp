import Foundation
import SwiftUI
import CryptoKit

/// Google OAuth service protocol
public protocol GoogleOAuthServiceProtocol {
    var isAuthorized: Bool { get }
    var isAuthorizing: Bool { get }
    func startOAuth()
    func cancelOAuth()
    func handleAuthCode(_ code: String)
    func clearAuthorization()
}

/// Google OAuth service implementation using Core modules
@MainActor
public final class GoogleOAuthService: ObservableObject, GoogleOAuthServiceProtocol {
    public static let shared = GoogleOAuthService()
    
    @Published public private(set) var isAuthorized = false
    @Published public private(set) var isAuthorizing = false
    @Published public var showOAuthWebView = false
    @Published public var oauthURL: URL?
    
    private let userService: UserServiceProtocol
    private let apiService: APIServiceProtocol
    private let notificationCenter: NotificationCenter
    
    private let clientId: String
    private let redirectUri: String
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    public init(
        userService: UserServiceProtocol = UserService.shared,
        apiService: APIServiceProtocol = APIService.shared,
        notificationCenter: NotificationCenter = .default,
        clientId: String = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String ?? "",
        redirectUri: String = (Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String ?? "") + ":redirect_uri_path"
    ) {
        self.userService = userService
        self.apiService = apiService
        self.notificationCenter = notificationCenter
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
    
    public func startOAuth() {
        isAuthorizing = true
        
        guard let url = createAuthURL() else {
            isAuthorizing = false
            return
        }
        
        oauthURL = url
        showOAuthWebView = true
    }
    
    public func cancelOAuth() {
        isAuthorizing = false
        showOAuthWebView = false
        oauthURL = nil
    }
    
    public func handleAuthCode(_ code: String) {
        showOAuthWebView = false
        oauthURL = nil
        
        Task {
            await exchangeCodeForTokens(code)
        }
    }
    
    public func clearAuthorization() {
        Task {
            await clearAuthorizationAsync()
        }
    }
    
    private func createAuthURL() -> URL? {
        generatePKCEParameters()
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        
        let state = UUID().uuidString
        
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
    
    private func generatePKCEParameters() {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        codeVerifier = String((0..<128).map { _ in characters.randomElement()! })
        
        if let verifier = codeVerifier {
            codeChallenge = generateCodeChallenge(from: verifier)
        }
    }
    
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .ascii) else { return nil }
        
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        
        return hashData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func exchangeCodeForTokens(_ code: String) async {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            isAuthorizing = false
            return
        }
        
        var parameters: [String: String] = [
            "client_id": clientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]
        
        if let codeVerifier = codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = parameters.compactMap { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String,
               let refreshToken = json["refresh_token"] as? String {
                
                isAuthorizing = false
                
                await MainActor.run {
                    sendTokensToServer(accessToken: accessToken, refreshToken: refreshToken)
                    
                    notificationCenter.post(name: .googleOAuthSuccess, object: nil)
                }
            } else {
                isAuthorizing = false
            }
        } catch {
            isAuthorizing = false
            print("Token exchange error: \(error)")
        }
    }
    
    private func sendTokensToServer(accessToken: String, refreshToken: String?) {
        guard let user = userService.currentUser else { return }
        
        Task {
            do {
                let endpoint = APIEndpoint(path: "/oauth/tokens", method: .post)
                var body: [String: Any] = [
                    "username": user.id,
                    "access_token": accessToken
                ]
                if let refreshToken = refreshToken {
                    body["refresh_token"] = refreshToken
                }
                
                let response = try await apiService.requestJSON(endpoint, body: body)
                
                if let status = response["status"] as? Bool, status {
                    isAuthorized = true
                    notificationCenter.post(name: .googleOAuthStatusChanged, object: nil)
                }
            } catch {
                print("Failed to send tokens to server: \(error)")
            }
        }
    }
    
    private func clearAuthorizationAsync() async {
        guard let user = userService.currentUser else { return }
        
        do {
            let endpoint = APIEndpoint(path: "/oauth/revoke", method: .post)
            let body = ["username": user.id]
            _ = try await apiService.requestJSON(endpoint, body: body)
            
            isAuthorized = false
            notificationCenter.post(name: .googleOAuthStatusChanged, object: nil)
        } catch {
            print("Failed to revoke authorization: \(error)")
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let googleOAuthSuccess = Notification.Name("GoogleOAuthSuccess")
    static let googleOAuthStatusChanged = Notification.Name("GoogleOAuthStatusChanged")
    static let googleOAuthWebViewDismissed = Notification.Name("GoogleOAuthWebViewDismissed")
}
