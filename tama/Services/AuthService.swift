import Foundation

/// Legacy Auth service wrapper using Core/Auth modules
/// Maintains backward compatibility while migrating to Core modules
final class AuthService {
    static let shared = AuthService()
    
    private let authService: AuthServiceProtocol
    private let cookieService: CookieServiceProtocol
    private let userService: UserServiceProtocol
    private let notificationCenter: NotificationCenter
    
    private init(
        authService: AuthServiceProtocol = Core.AuthService.shared,
        cookieService: CookieServiceProtocol = CookieService.shared,
        userService: UserServiceProtocol = UserService.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.authService = authService
        self.cookieService = cookieService
        self.userService = userService
        self.notificationCenter = notificationCenter
    }
    
    /// Login with credentials
    func login(
        account: String, password: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        Task {
            do {
                let response = try await authService.login(account: account, password: password)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Logout
    func logout(
        userId: String, encryptedPassword: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            do {
                let success = try await authService.logout()
                completion(.success(success))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case invalidResponse
    case loginFailed(String)
    case logoutFailed(String)
    case userDataNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "APIエンドポイントが無効です"
        case .requestCreationFailed:
            return "リクエストデータの作成に失敗しました"
        case .noDataReceived:
            return "データが受信できませんでした"
        case .decodingFailed:
            return "レスポンスのデコードに失敗しました"
        case .invalidResponse:
            return "レスポンスの解析に失敗しました"
        case .loginFailed(let message):
            return message
        case .logoutFailed(let message):
            return message
        case .userDataNotFound:
            return "ユーザーデータが見つかりません"
        }
    }
}
