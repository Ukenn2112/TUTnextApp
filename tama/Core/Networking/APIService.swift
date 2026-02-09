import Foundation

// MARK: - APIService Protocol

protocol APIServiceProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> T
    func requestJSON(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> [String: Any]
    func requestData(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> Data
}

// MARK: - APIService

/// Main API service that wraps NetworkClient with business-logic-specific methods
@MainActor
final class APIService: APIServiceProtocol {
    static let shared = APIService()
    
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }
    
    // MARK: - Generic Request Methods
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> T {
        try await networkClient.request(endpoint, body: body)
    }
    
    func requestJSON(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> [String: Any] {
        try await networkClient.requestJSON(endpoint, body: body)
    }
    
    func requestData(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> Data {
        try await networkClient.request(endpoint, body: body)
    }
    
    // MARK: - Login
    
    func login(account: String, password: String) async throws -> [String: Any] {
        let endpoint = APIEndpoint(
            path: "/up/pk/Pky001Resource/login",
            method: .post
        )
        
        let body: [String: Any] = [
            "data": [
                "loginUserId": account,
                "plainLoginPassword": password
            ]
        ]
        
        return try await requestJSON(endpoint, body: body)
    }
    
    // MARK: - Logout
    
    func logout(userId: String, encryptedPassword: String) async throws -> Bool {
        let endpoint = APIEndpoint(
            path: "/up/pk/Pky002Resource/logout",
            method: .post
        )
        
        let body: [String: Any] = [
            "subProductCd": "apa",
            "plainLoginPassword": "",
            "loginUserId": userId,
            "langCd": "",
            "productCd": "ap",
            "encryptedLoginPassword": encryptedPassword
        ]
        
        let response = try await requestJSON(endpoint, body: body)
        
        guard let statusDto = response["statusDto"] as? [String: Any],
              let success = statusDto["success"] as? Bool else {
            throw AppError.invalidResponseFormat
        }
        
        return success
    }
    
    // MARK: - Timetable
    
    func fetchTimetable(semesterCd: String) async throws -> [String: Any] {
        let endpoint = APIEndpoint(
            path: "/up/pk/pkx001Resource/getClassTable",
            method: .post
        )
        
        let body: [String: Any] = [
            "data": [
                "termCd": semesterCd
            ]
        ]
        
        return try await requestJSON(endpoint, body: body)
    }
    
    // MARK: - Course Details
    
    func fetchCourseDetails(courseId: String) async throws -> [String: Any] {
        let endpoint = APIEndpoint(
            path: "/up/pk/pkx002Resource/getDetailInfo",
            method: .post
        )
        
        let body: [String: Any] = [
            "data": [
                "courseCd": courseId
            ]
        ]
        
        return try await requestJSON(endpoint, body: body)
    }
    
    // MARK: - User Profile
    
    func fetchUserProfile() async throws -> [String: Any] {
        let endpoint = APIEndpoint(
            path: "/up/pk/pky010Resource/getUserInfo",
            method: .post
        )
        
        let body: [String: Any] = [
            "data": [:]
        ]
        
        return try await requestJSON(endpoint, body: body)
    }
}

// MARK: - API Endpoints

extension APIService {
    enum Endpoints {
        // Authentication
        static let login = APIEndpoint(path: "/up/pk/Pky001Resource/login", method: .post)
        static let logout = APIEndpoint(path: "/up/pk/Pky002Resource/logout", method: .post)
        
        // Timetable
        static let timetable = APIEndpoint(path: "/up/pk/pkx001Resource/getClassTable", method: .post)
        
        // Course Details
        static let courseDetails = APIEndpoint(path: "/up/pk/pkx002Resource/getDetailInfo", method: .post)
        
        // User
        static let userProfile = APIEndpoint(path: "/up/pk/pky010Resource/getUserInfo", method: .post)
        
        // Assignments
        static let assignments = APIEndpoint(path: "/up/pk/pkx004Resource/getAssignmentInfo", method: .post)
        
        // Bus Schedule
        static let busSchedule = APIEndpoint(path: "/up/pk/pkx003Resource/getBusSchedule", method: .post)
    }
}

// MARK: - Request Builder

struct APIRequestBuilder {
    private var method: HTTPMethod = .get
    private var path: String = ""
    private var headers: [String: String]?
    private var queryItems: [URLQueryItem]?
    private var body: [String: Any]?
    
    static func `default`() -> APIRequestBuilder {
        APIRequestBuilder()
    }
    
    func method(_ method: HTTPMethod) -> APIRequestBuilder {
        var builder = self
        builder.method = method
        return builder
    }
    
    func path(_ path: String) -> APIRequestBuilder {
        var builder = self
        builder.path = path
        return builder
    }
    
    func headers(_ headers: [String: String]?) -> APIRequestBuilder {
        var builder = self
        builder.headers = headers
        return builder
    }
    
    func queryItems(_ queryItems: [URLQueryItem]?) -> APIRequestBuilder {
        var builder = self
        builder.queryItems = queryItems
        return builder
    }
    
    func body(_ body: [String: Any]?) -> APIRequestBuilder {
        var builder = self
        builder.body = body
        return builder
    }
    
    func build() -> APIEndpoint {
        APIEndpoint(
            path: path,
            method: method,
            headers: headers,
            queryItems: queryItems
        )
    }
}
