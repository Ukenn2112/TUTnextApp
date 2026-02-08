import Foundation

/// Protocol for network client operations
public protocol NetworkClientProtocol {
    /// Perform a network request and decode response
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    
    /// Perform a network request without decoding
    func requestRaw(_ endpoint: APIEndpoint) async throws -> Data
}

/// Network errors
public enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case unauthorized
    case notFound
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .notFound:
            return "Resource not found"
        case .timeout:
            return "Request timeout"
        }
    }
}

/// API endpoint configuration
public enum APIEndpoint {
    case users(UsersEndpoint)
    case timetable(TimetableEndpoint)
    case bus(BusEndpoint)
    case assignments(AssignmentsEndpoint)
    
    public var path: String {
        switch self {
        case .users(let endpoint):
            return "/api/users/\(endpoint.path)"
        case .timetable(let endpoint):
            return "/api/timetable/\(endpoint.path)"
        case .bus(let endpoint):
            return "/api/bus/\(endpoint.path)"
        case .assignments(let endpoint):
            return "/api/assignments/\(endpoint.path)"
        }
    }
    
    public var method: HTTPMethod {
        switch self {
        case .users(let endpoint):
            return endpoint.method
        case .timetable(let endpoint):
            return endpoint.method
        case .bus(let endpoint):
            return endpoint.method
        case .assignments(let endpoint):
            return endpoint.method
        }
    }
    
    public var headers: [String: String] {
        switch self {
        case .users:
            return ["Content-Type": "application/json"]
        case .timetable:
            return ["Content-Type": "application/json"]
        case .bus:
            return ["Content-Type": "application/json"]
        case .assignments:
            return ["Content-Type": "application/json"]
        }
    }
    
    public var body: Data? {
        switch self {
        case .users(let endpoint):
            return endpoint.body
        case .timetable(let endpoint):
            return endpoint.body
        case .bus(let endpoint):
            return endpoint.body
        case .assignments(let endpoint):
            return endpoint.body
        }
    }
}

/// HTTP methods
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Users Endpoints

public enum UsersEndpoint {
    case fetchCurrent
    case updateProfile(UserProfileUpdate)
    case login(UserCredentials)
    case logout
    case refreshToken(String)
    case updateDeviceToken(String)
    case getUnreadCount
    
    var path: String {
        switch self {
        case .fetchCurrent:
            return "current"
        case .updateProfile:
            return "profile"
        case .login:
            return "login"
        case .logout:
            return "logout"
        case .refreshToken:
            return "refresh"
        case .updateDeviceToken:
            return "device-token"
        case .getUnreadCount:
            return "unread-count"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .fetchCurrent, .getUnreadCount:
            return .get
        case .updateProfile, .updateDeviceToken:
            return .put
        case .login:
            return .post
        case .logout, .refreshToken:
            return .post
        }
    }
    
    var body: Data? {
        switch self {
        case .updateProfile(let profile):
            return try? JSONEncoder().encode(profile)
        case .login(let credentials):
            return try? JSONEncoder().encode(credentials)
        case .refreshToken(let token):
            return try? JSONEncoder().encode(["refreshToken": token])
        case .updateDeviceToken(let token):
            return try? JSONEncoder().encode(["deviceToken": token])
        default:
            return nil
        }
    }
}

// MARK: - Timetable Endpoints

public enum TimetableEndpoint {
    case fetch(userId: String)
    case fetch(semesterId: String)
    case fetchCourseDetail(courseId: String)
    case updateColor(courseId: String, colorIndex: Int)
    case fetchSemesters
    
    var path: String {
        switch self {
        case .fetch(let userId):
            return "user/\(userId)"
        case .fetch(let semesterId):
            return "semester/\(semesterId)"
        case .fetchCourseDetail(let courseId):
            return "course/\(courseId)/detail"
        case .updateColor(let courseId, _):
            return "course/\(courseId)/color"
        case .fetchSemesters:
            return "semesters"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .fetch, .fetchCourseDetail, .fetchSemesters:
            return .get
        case .updateColor:
            return .put
        }
    }
    
    var body: Data? {
        switch self {
        case .updateColor(_, let colorIndex):
            return try? JSONEncoder().encode(["colorIndex": colorIndex])
        default:
            return nil
        }
    }
}

// MARK: - Bus Endpoints

public enum BusEndpoint {
    case fetchSchedule
    case fetchTemporaryMessages
    case refresh
    
    var path: String {
        switch self {
        case .fetchSchedule:
            return "schedule"
        case .fetchTemporaryMessages:
            return "messages"
        case .refresh:
            return "refresh"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .fetchSchedule, .fetchTemporaryMessages:
            return .get
        case .refresh:
            return .post
        }
    }
}

// MARK: - Assignments Endpoints

public enum AssignmentsEndpoint {
    case fetchAll
    case fetch(id: String)
    case submit(assignmentId: String, submission: AssignmentSubmission)
    case updateStatus(assignmentId: String, status: AssignmentStatus)
    
    var path: String {
        switch self {
        case .fetchAll:
            return ""
        case .fetch(let id):
            return id
        case .submit(let assignmentId, _):
            return "\(assignmentId)/submit"
        case .updateStatus(let assignmentId, _):
            return "\(assignmentId)/status"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .fetchAll, .fetch:
            return .get
        case .submit:
            return .post
        case .updateStatus:
            return .patch
        }
    }
    
    var body: Data? {
        switch self {
        case .submit(_, let submission):
            return try? JSONEncoder().encode(submission)
        case .updateStatus(_, let status):
            return try? JSONEncoder().encode(["status": status.rawValue])
        default:
            return nil
        }
    }
}
