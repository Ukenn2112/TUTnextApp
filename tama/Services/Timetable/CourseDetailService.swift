import Foundation

/// Course detail service protocol
public protocol CourseDetailServiceProtocol {
    func fetchCourseDetail(courseId: String) async throws -> CourseDetail
    func fetchCourseDetail(for course: Course) async throws -> CourseDetail
    func saveMemo(courseId: String, memo: String) async throws
}

/// Course detail service implementation using Core modules
@MainActor
public final class CourseDetailService: CourseDetailServiceProtocol {
    public static let shared = CourseDetailService()
    
    private let repository: TimetableRepositoryProtocol
    private let sessionManager: SessionManagerProtocol
    private let apiService: APIServiceProtocol
    
    public init(
        repository: TimetableRepositoryProtocol = TimetableRepository(
            networkClient: NetworkClient.shared,
            storage: Storage.shared,
            userId: SessionManager.shared.userId ?? ""
        ),
        sessionManager: SessionManagerProtocol = SessionManager.shared,
        apiService: APIServiceProtocol = APIService.shared
    ) {
        self.repository = repository
        self.sessionManager = sessionManager
        self.apiService = apiService
    }
    
    public func fetchCourseDetail(courseId: String) async throws -> CourseDetail {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        do {
            return try await repository.fetchCourseDetail(courseId: courseId)
        } catch {
            throw AppError.network(.noConnection)
        }
    }
    
    public func fetchCourseDetail(for course: Course) async throws -> CourseDetail {
        guard let courseId = course.jugyoCd else {
            throw AppError.validation(.invalidFormat(field: "courseId"))
        }
        
        return try await fetchCourseDetail(courseId: courseId)
    }
    
    public func saveMemo(courseId: String, memo: String) async throws {
        guard sessionManager.isAuthenticated else {
            throw AppError.auth(.sessionExpired)
        }
        
        // Use the APIService directly for memo saving
        // This is a placeholder - actual implementation would call the appropriate API endpoint
        // The memo saving functionality is available through the existing API infrastructure
    }
}
