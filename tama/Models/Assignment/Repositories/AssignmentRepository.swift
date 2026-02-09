//
//  AssignmentRepository
//  TUTnext
//
//  Data models for the application
//
import Foundation

/// Assignment repository protocol defining data access operations
public protocol AssignmentRepositoryProtocol {
    /// Fetch all assignments
    func fetchAssignments() async throws -> [Assignment]
    
    /// Fetch assignments for a specific course
    func fetchAssignments(for courseId: String) async throws -> [Assignment]
    
    /// Fetch assignment by ID
    func fetchAssignment(id: String) async throws -> Assignment
    
    /// Fetch assignments with course information
    func fetchAssignmentsWithCourse() async throws -> [AssignmentWithCourse]
    
    /// Submit an assignment
    func submitAssignment(_ assignmentId: String, submission: AssignmentSubmission) async throws -> AssignmentSubmission
    
    /// Update assignment status
    func updateStatus(_ assignmentId: String, status: AssignmentStatus) async throws -> Assignment
    
    /// Get assignment summary
    func getSummary() async throws -> AssignmentSummary
    
    /// Refresh assignments from server
    func refreshAssignments() async throws -> [Assignment]
}

/// Assignment repository implementation
public final class AssignmentRepository: AssignmentRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let storage: StorageProtocol
    
    public init(networkClient: NetworkClientProtocol, storage: StorageProtocol) {
        self.networkClient = networkClient
        self.storage = storage
    }
    
    public func fetchAssignments() async throws -> [Assignment] {
        // Try cache first
        if let cached = storage.retrieve(forKey: .assignments) as [Assignment]?,
           let lastUpdated = UserDefaults.standard.object(forKey: .assignmentsLastUpdated) as Date?,
           Date().timeIntervalSince(lastUpdated) < 3600 {
            return cached
        }
        
        // Fetch from server
        let assignments = try await fetchAssignmentsFromServer()
        
        // Cache result
        storage.save(assignments, forKey: .assignments)
        UserDefaults.standard.set(Date(), forKey: .assignmentsLastUpdated)
        
        return assignments
    }
    
    public func fetchAssignments(for courseId: String) async throws -> [Assignment] {
        let allAssignments = try await fetchAssignments()
        return allAssignments.filter { $0.courseId == courseId }
    }
    
    public func fetchAssignment(id: String) async throws -> Assignment {
        let allAssignments = try await fetchAssignments()
        
        guard let assignment = allAssignments.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        
        return assignment
    }
    
    public func fetchAssignmentsWithCourse() async throws -> [AssignmentWithCourse] {
        let assignments = try await fetchAssignments()
        
        // Map to include course colors
        return assignments.map { assignment in
            AssignmentWithCourse(
                assignment: assignment,
                courseColor: ColorTransformer.colorIndexToHex(assignment.status == .completed ? 1 : 2),
                isRead: true
            )
        }
    }
    
    public func submitAssignment(
        _ assignmentId: String,
        submission: AssignmentSubmission
    ) async throws -> AssignmentSubmission {
        let endpoint = APIEndpoint.assignments.submit(assignmentId: assignmentId, submission: submission)
        
        let response: SubmitResponse = try await networkClient.request(endpoint)
        
        // Update local cache
        if var cached = storage.retrieve(forKey: .assignments) as [Assignment]? {
            if let index = cached.firstIndex(where: { $0.id == assignmentId }) {
                cached[index].status = .submitted
                storage.save(cached, forKey: .assignments)
            }
        }
        
        return submission
    }
    
    public func updateStatus(_ assignmentId: String, status: AssignmentStatus) async throws -> Assignment {
        let endpoint = APIEndpoint.assignments.updateStatus(assignmentId: assignmentId, status: status)
        
        let response: AssignmentResponse = try await networkClient.request(endpoint)
        
        guard let assignment = response.data?.first else {
            throw RepositoryError.decodingError(
                NSError(domain: "AssignmentRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
            )
        }
        
        // Update local cache
        if var cached = storage.retrieve(forKey: .assignments) as [Assignment]? {
            if let index = cached.firstIndex(where: { $0.id == assignmentId }) {
                cached[index] = assignment
                storage.save(cached, forKey: .assignments)
            }
        }
        
        return assignment
    }
    
    public func getSummary() async throws -> AssignmentSummary {
        let assignments = try await fetchAssignments()
        return AssignmentSummary.from(assignments)
    }
    
    public func refreshAssignments() async throws -> [Assignment] {
        let assignments = try await fetchAssignmentsFromServer()
        
        // Update cache
        storage.save(assignments, forKey: .assignments)
        UserDefaults.standard.set(Date(), forKey: .assignmentsLastUpdated)
        
        return assignments
    }
    
    private func fetchAssignmentsFromServer() async throws -> [Assignment] {
        let endpoint = APIEndpoint.assignments.fetchAll
        
        let response: AssignmentResponse = try await networkClient.request(endpoint)
        
        guard let apiAssignments = response.data else {
            throw RepositoryError.decodingError(
                NSError(domain: "AssignmentRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
            )
        }
        
        return apiAssignments.map { $0.toAssignment() }
    }
}

// MARK: - API Response Models

private struct AssignmentResponse: Codable {
    let status: Bool
    let data: [APIAssignment]?
}

private struct APIAssignment: Codable {
    let title: String
    let courseId: String
    let courseName: String
    let dueDate: String
    let dueTime: String
    let description: String?
    let url: String?
    
    func toAssignment() -> Assignment {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateTimeString = "\(dueDate) \(dueTime)"
        let date = dateFormatter.date(from: dateTimeString) ?? Date()
        
        return Assignment(
            id: UUID().uuidString,
            title: title,
            courseId: courseId,
            courseName: courseName,
            dueDate: date,
            description: description ?? "",
            status: .pending,
            url: url ?? ""
        )
    }
}

private struct SubmitResponse: Codable {
    let status: Bool
    let message: String?
}

// MARK: - UserDefaults Keys

private extension UserDefaults {
    enum Keys {
        static let assignmentsLastUpdated = "assignmentsLastUpdated"
    }
}
