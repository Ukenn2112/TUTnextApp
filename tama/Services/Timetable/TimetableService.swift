import Foundation

/// Timetable service protocol
public protocol TimetableServiceProtocol {
    func fetchTimetable() async throws -> Timetable
    func fetchTimetable(for semester: Semester) async throws -> Timetable
    func refreshTimetable() async throws -> Timetable
    func getCachedTimetable() -> Timetable?
    func updateCourseColor(courseId: String, colorIndex: Int) async throws
}

/// Timetable service implementation using Core modules
public final class TimetableService: TimetableServiceProtocol {
    public static let shared = TimetableService()
    
    private let repository: TimetableRepositoryProtocol
    private let sessionManager: SessionManagerProtocol
    private let notificationCenter: NotificationCenter
    
    public init(
        repository: TimetableRepositoryProtocol = TimetableRepository(
            networkClient: NetworkClient.shared,
            storage: Storage.shared,
            userId: SessionManager.shared.userId ?? ""
        ),
        sessionManager: SessionManagerProtocol = SessionManager.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.repository = repository
        self.sessionManager = sessionManager
        self.notificationCenter = notificationCenter
    }
    
    public func fetchTimetable() async throws -> Timetable {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        do {
            let timetable = try await repository.fetchTimetable()
            notificationCenter.post(name: .timetableDidUpdate, object: timetable)
            return timetable
        } catch {
            throw AppError.network(.noConnection)
        }
    }
    
    public func fetchTimetable(for semester: Semester) async throws -> Timetable {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        do {
            return try await repository.fetchTimetable(for: semester)
        } catch {
            throw AppError.network(.noConnection)
        }
    }
    
    public func refreshTimetable() async throws -> Timetable {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        let timetable = try await repository.refreshTimetable()
        notificationCenter.post(name: .timetableDidUpdate, object: timetable)
        return timetable
    }
    
    public func getCachedTimetable() -> Timetable? {
        guard let repository = repository as? TimetableRepository else { return nil }
        // Return cached data through repository
        return try? (repository as TimetableRepository).fetchTimetable().get()
    }
    
    public func updateCourseColor(courseId: String, colorIndex: Int) async throws {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        try await repository.updateCourseColor(courseId: courseId, colorIndex: colorIndex)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let timetableDidUpdate = Notification.Name("TimetableDidUpdate")
    static let timetableDidFailToUpdate = Notification.Name("TimetableDidFailToUpdate")
}
