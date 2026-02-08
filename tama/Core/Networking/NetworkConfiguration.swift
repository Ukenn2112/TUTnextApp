import Foundation

// MARK: - API Error Definitions

enum APIError: LocalizedError {
    case invalidURL
    case requestCreationFailed
    case noData
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkUnavailable
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestCreationFailed:
            return "Failed to create request"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Forbidden access"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection"
        case .timeout:
            return "Please try again"
        case .unauthorized:
            return "Please log in again"
        default:
            return nil
        }
    }
}

// MARK: - HTTP Methods

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Endpoint Protocol

protocol APIEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: String]? { get }
    var bodyParameters: [String: Any]? { get }
}

extension APIEndpoint {
    var headers: [String: String]? { nil }
    var queryParameters: [String: String]? { nil }
    var bodyParameters: [String: Any]? { nil }
    
    func urlRequest() throws -> URLRequest {
        var components = URLComponents(string: baseURL + path)
        
        if let queryParameters = queryParameters {
            components?.queryItems = queryParameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let bodyParameters = bodyParameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParameters)
        }
        
        return request
    }
}

// MARK: - API Configuration

struct APIConfiguration {
    let baseURL: String
    let timeout: TimeInterval
    let retryCount: Int
    let retryDelay: TimeInterval
    
    static let `default` = APIConfiguration(
        baseURL: "https://next.tama.ac.jp/uprx/webapi",
        timeout: 30.0,
        retryCount: 3,
        retryDelay: 1.0
    )
}

// MARK: - Request Interceptor Protocol

protocol RequestInterceptor {
    func intercept(request: URLRequest) async throws -> URLRequest
}

// MARK: - Response Interceptor Protocol

protocol ResponseInterceptor {
    func intercept(response: URLResponse, data: Data) async throws -> (URLResponse, Data)
}
