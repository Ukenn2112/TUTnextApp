import Foundation

// MARK: - Legacy AuthService Wrapper
// Uses Core.Auth.AuthService for implementation

@MainActor
@available(*, deprecated, message: "Use Core.Auth.AuthService instead")
final class AuthService {
    static let shared = AuthService()
    
    private let authService: Core.Auth.AuthService
    
    private init() {
        self.authService = Core.Auth.AuthService.shared
    }
    
    /// Login with credentials (legacy wrapper)
    func login(
        account: String, password: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        Task {
            do {
                let response = try await authService.login(account: account, password: password)
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Logout (legacy wrapper)
    func logout(
        userId: String, encryptedPassword: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        Task {
            do {
                let success = try await authService.logout()
                await MainActor.run {
                    completion(.success(success))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
