import Foundation

/// User repository protocol defining data access operations
public protocol UserRepositoryProtocol {
    /// Fetch current user profile
    func fetchCurrentUser() async throws -> User
    
    /// Update user profile
    func updateProfile(_ profile: UserProfileUpdate) async throws -> User
    
    /// Login with credentials
    func login(credentials: UserCredentials) async throws -> UserSession
    
    /// Logout current session
    func logout() async throws
    
    /// Refresh authentication token
    func refreshToken() async throws -> AuthToken
    
    /// Update device token for push notifications
    func updateDeviceToken(_ token: String) async throws
    
    /// Get unread notification count
    func getUnreadCount() async throws -> Int
}

/// User repository implementation
public final class UserRepository: UserRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let storage: StorageProtocol
    private var currentSession: UserSession?
    
    public init(networkClient: NetworkClientProtocol, storage: StorageProtocol) {
        self.networkClient = networkClient
        self.storage = storage
        self.currentSession = nil
    }
    
    public func fetchCurrentUser() async throws -> User {
        // Simulated API call - replace with actual endpoint
        let endpoint = APIEndpoint.users.fetchCurrent
        
        do {
            let user: User = try await networkClient.request(endpoint)
            return user
        } catch {
            // Fallback to cached user if available
            if let cachedUser = storage.retrieve(forKey: .currentUser) as User? {
                return cachedUser
            }
            throw error
        }
    }
    
    public func updateProfile(_ profile: UserProfileUpdate) async throws -> User {
        let endpoint = APIEndpoint.users.updateProfile(profile)
        
        let updatedUser: User = try await networkClient.request(endpoint)
        
        // Update cached user
        storage.save(updatedUser, forKey: .currentUser)
        
        return updatedUser
    }
    
    public func login(credentials: UserCredentials) async throws -> UserSession {
        try credentials.validate()
        
        let endpoint = APIEndpoint.users.login(credentials)
        
        let session: UserSession = try await networkClient.request(endpoint)
        
        // Store session
        currentSession = session
        storage.save(session, forKey: .userSession)
        
        return session
    }
    
    public func logout() async throws {
        let endpoint = APIEndpoint.users.logout
        
        do {
            _ = try await networkClient.request(endpoint)
        } catch {
            // Continue with local logout even if API call fails
        }
        
        // Clear stored session
        currentSession = nil
        storage.remove(forKey: .userSession)
    }
    
    public func refreshToken() async throws -> AuthToken {
        guard let currentToken = currentSession?.token.refreshToken else {
            throw RepositoryError.notAuthenticated
        }
        
        let endpoint = APIEndpoint.users.refreshToken(currentToken)
        
        let newToken: AuthToken = try await networkClient.request(endpoint)
        
        // Update stored token
        if var session = currentSession {
            session.token = newToken
            currentSession = session
            storage.save(session, forKey: .userSession)
        }
        
        return newToken
    }
    
    public func updateDeviceToken(_ token: String) async throws {
        let endpoint = APIEndpoint.users.updateDeviceToken(token)
        
        _ = try await networkClient.request(endpoint)
    }
    
    public func getUnreadCount() async throws -> Int {
        let endpoint = APIEndpoint.users.getUnreadCount
        
        let response: UnreadCountResponse = try await networkClient.request(endpoint)
        return response.count
    }
}

// MARK: - Supporting Types

private struct UnreadCountResponse: Codable {
    let count: Int
}

// MARK: - Repository Errors

public enum RepositoryError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case notFound
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
