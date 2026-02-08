import Foundation

// MARK: - AuthService Protocol

protocol AuthServiceProtocol {
    func login(account: String, password: String) async throws -> [String: Any]
    func logout() async throws -> Bool
    func refreshTokenIfNeeded() async throws
    func isAuthenticated() -> Bool
}

// MARK: - AuthService

/// Handles authentication operations including login, logout, and token refresh
final class AuthService: AuthServiceProtocol {
    static let shared = AuthService()
    
    private let apiService: APIServiceProtocol
    private let sessionManager: SessionManagerProtocol
    private let cookieService: CookieServiceProtocol
    private let userService: UserServiceProtocol
    
    init(
        apiService: APIServiceProtocol = APIService.shared,
        sessionManager: SessionManagerProtocol = SessionManager.shared,
        cookieService: CookieServiceProtocol = CookieService.shared,
        userService: UserServiceProtocol = UserService.shared
    ) {
        self.apiService = apiService
        self.sessionManager = sessionManager
        self.cookieService = cookieService
        self.userService = userService
    }
    
    // MARK: - Login
    
    func login(account: String, password: String) async throws -> [String: Any] {
        let response = try await apiService.login(account: account, password: password)
        
        // Parse and save session
        if let data = response["data"] as? [String: Any],
           let accessToken = data["accessToken"] as? String,
           let userId = data["loginUserId"] as? String {
            
            let refreshToken = data["refreshToken"] as? String
            
            sessionManager.saveSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: userId,
                encryptedPassword: nil
            )
        }
        
        // Notify session change
        SessionNotificationCenter.shared.notifySessionChange(.current)
        
        return response
    }
    
    // MARK: - Logout
    
    func logout() async throws -> Bool {
        guard let userId = sessionManager.userId,
              let encryptedPassword = sessionManager.encryptedPassword else {
            // No session to logout, just clear local data
            performLocalLogout()
            return true
        }
        
        do {
            let success = try await apiService.logout(
                userId: userId,
                encryptedPassword: encryptedPassword
            )
            
            performLocalLogout()
            return success
            
        } catch {
            // Even if API call fails, clear local session
            performLocalLogout()
            throw AppError.logoutFailed
        }
    }
    
    private func performLocalLogout() {
        // Clear session data
        sessionManager.clearSession()
        
        // Clear cookies
        cookieService.clearCookies()
        
        // Clear user data
        userService.clearCurrentUser()
        
        // Notify observers
        SessionNotificationCenter.shared.notifySessionLogout()
        SessionNotificationCenter.shared.notifySessionChange(.empty)
    }
    
    // MARK: - Token Refresh
    
    func refreshTokenIfNeeded() async throws {
        // Check if we have a refresh token
        guard let refreshToken = sessionManager.refreshToken else {
            throw AppError.refreshTokenFailed
        }
        
        // In a real implementation, you would call a token refresh endpoint
        // For now, this is a placeholder
        // try await apiService.refreshToken(refreshToken: refreshToken)
    }
    
    // MARK: - Authentication Check
    
    func isAuthenticated() -> Bool {
        sessionManager.isAuthenticated
    }
}

// MARK: - Auth State

enum AuthState {
    case authenticated
    case unauthenticated
    case loading
    case error(AppError)
    
    static var current: AuthState {
        if AuthService.shared.isAuthenticated() {
            return .authenticated
        }
        return .unauthenticated
    }
}

// MARK: - Auth Extensions

extension AuthService {
    /// Convenience method to require authentication
    func requireAuth() throws {
        guard isAuthenticated() else {
            throw AppError.unauthorized
        }
    }
    
    /// Get current user ID
    func getCurrentUserId() -> String? {
        sessionManager.userId
    }
    
    /// Get current access token
    func getAccessToken() -> String? {
        sessionManager.accessToken
    }
}
