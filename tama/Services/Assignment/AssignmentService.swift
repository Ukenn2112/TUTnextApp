//
//  AssignmentService
//  TUTnext
//
//  Service layer implementation using Core modules
//
import Foundation
import UserNotifications

/// Assignment service protocol
public protocol AssignmentServiceProtocol {
    func fetchAssignments() async throws -> [Assignment]
    func getCachedAssignments() -> [Assignment]?
    func handleAssignmentCountChange(count: Int)
}

/// Assignment service implementation using Core modules
@MainActor
public final class AssignmentService: AssignmentServiceProtocol {
    public static let shared = AssignmentService()
    
    private let repository: AssignmentRepositoryProtocol
    private let userService: UserServiceProtocol
    private let notificationCenter: NotificationCenter
    
    public init(
        repository: AssignmentRepositoryProtocol = AssignmentRepository(
            networkClient: NetworkClient.shared,
            userId: SessionManager.shared.userId ?? ""
        ),
        userService: UserServiceProtocol = UserService.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.repository = repository
        self.userService = userService
        self.notificationCenter = notificationCenter
    }
    
    public func fetchAssignments() async throws -> [Assignment] {
        guard userService.currentUser != nil else {
            throw AppError.auth(.sessionExpired)
        }
        
        do {
            let assignments = try await repository.fetchAssignments()
            
            // Post notification for UI updates
            notificationCenter.post(
                name: .assignmentsDidUpdate,
                object: nil,
                userInfo: ["count": assignments.count]
            )
            
            return assignments
        } catch {
            throw AppError.network(.noConnection)
        }
    }
    
    public func getCachedAssignments() -> [Assignment]? {
        repository.getCachedAssignments()
    }
    
    public func handleAssignmentCountChange(count: Int) {
        notificationCenter.post(
            name: .assignmentsDidUpdate,
            object: nil,
            userInfo: ["count": count]
        )
        
        // Update app badge
        updateApplicationBadge(count: count)
    }
    
    private func updateApplicationBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("Badge update error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Assignment Repository Protocol

public protocol AssignmentRepositoryProtocol {
    func fetchAssignments() async throws -> [Assignment]
    func getCachedAssignments() -> [Assignment]?
}

/// Assignment repository implementation
public final class AssignmentRepository: AssignmentRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let userId: String
    private let storage: StorageProtocol
    
    public init(networkClient: NetworkClientProtocol, userId: String, storage: StorageProtocol = Storage.shared) {
        self.networkClient = networkClient
        self.userId = userId
        self.storage = storage
    }
    
    public func fetchAssignments() async throws -> [Assignment] {
        // Implementation would use the existing API endpoint
        // For now, return empty array as placeholder
        // Actual implementation would call the assignment API
        return []
    }
    
    public func getCachedAssignments() -> [Assignment]? {
        storage.retrieve(forKey: .assignments) as [Assignment]?
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let assignmentsDidUpdate = Notification.Name("AssignmentsDidUpdate")
    static let assignmentsDidFailToUpdate = Notification.Name("AssignmentsDidFailToUpdate")
}
