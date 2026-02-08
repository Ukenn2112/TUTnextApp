import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Endpoint

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    
    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
    }
}

// MARK: - API Configuration

struct APIConfiguration {
    let baseURL: String
    let timeout: TimeInterval
    let defaultHeaders: [String: String]
    let retryPolicy: RetryPolicy
    
    static let `default` = APIConfiguration(
        baseURL: "https://next.tama.ac.jp/uprx/webapi",
        timeout: 30,
        defaultHeaders: [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ],
        retryPolicy: .exponential(maxDelay: 30, maxAttempts: 3)
    )
    
    static let development = APIConfiguration(
        baseURL: "https://dev.next.tama.ac.jp/uprx/webapi",
        timeout: 60,
        defaultHeaders: [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ],
        retryPolicy: .retry(count: 5, delay: 5)
    )
}

// MARK: - NetworkClient Protocol

protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> T
    func request(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> Data
    func requestJSON(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> [String: Any]
}

// MARK: - NetworkClient

final class NetworkClient: NetworkClientProtocol {
    static let shared = NetworkClient()
    
    private let configuration: APIConfiguration
    private let session: URLSession
    private let interceptorChain: InterceptorChain
    private let decoder: JSONDecoder
    
    init(
        configuration: APIConfiguration = .default,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.interceptorChain = InterceptorChain()
        self.decoder = JSONDecoder()
        
        setupDefaultInterceptors()
    }
    
    private func setupDefaultInterceptors() {
        let loggingInterceptor = LoggingInterceptor(logTag: "Network", verbose: false)
        interceptorChain.add(loggingInterceptor)
    }
    
    func addInterceptor(_ interceptor: NetworkInterceptor) {
        interceptorChain.add(interceptor)
    }
    
    // MARK: - Request Methods
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> T {
        let data = try await request(endpoint, body: body)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decodingError(underlying: error)
        }
    }
    
    func request(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> Data {
        let request = try buildRequest(for: endpoint, body: body)
        let interceptedRequest = interceptorChain.processRequest(request)
        
        var attempt = 0
        var lastError: AppError?
        
        while true {
            attempt += 1
            
            do {
                let (data, response) = try await session.data(for: interceptedRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw AppError.from(statusCode: httpResponse.statusCode)
                }
                
                let (_, processedData) = interceptorChain.processResponse(response, data: data)
                return processedData
                
            } catch let error as AppError {
                lastError = error
                
                // Check if we should retry
                if let retryDelay = shouldRetry(error: error, attempt: attempt) {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                
                throw interceptorChain.processError(error, attempt: attempt)
                
            } catch {
                let appError = AppError.networkError(underlying: error)
                if let retryDelay = shouldRetry(error: appError, attempt: attempt) {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                throw appError
            }
        }
    }
    
    func requestJSON(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> [String: Any] {
        let data = try await request(endpoint, body: body)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.invalidResponseFormat
        }
        
        return json
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest(for endpoint: APIEndpoint, body: [String: Any]?) throws -> URLRequest {
        // Build URL with query items
        var components = URLComponents(string: configuration.baseURL + endpoint.path)
        components?.queryItems = endpoint.queryItems
        
        guard let url = components?.url else {
            throw AppError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = configuration.timeout
        
        // Apply default headers
        for (key, value) in configuration.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Apply endpoint-specific headers
        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add body if present
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func shouldRetry(error: AppError, attempt: Int) -> TimeInterval? {
        // Only retry on network errors or server errors (5xx)
        let retryableErrors: [AppError] = [
            .networkError(underlying: NSError(domain: "", code: -1)),
            .timeout,
            .httpError(statusCode: 500),
            .httpError(statusCode: 503)
        ]
        
        switch error {
        case .networkError, .timeout, .httpError:
            return configuration.retryPolicy.shouldRetry(attempt: attempt, error: error)?.1
        default:
            return nil
        }
    }
}

// MARK: - Mock NetworkClient for Previews

#if DEBUG
final class MockNetworkClient: NetworkClientProtocol {
    var mockData: Data?
    var mockError: Error?
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> T {
        if let error = mockError {
            throw error
        }
        guard let data = mockData else {
            throw AppError.noData
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func request(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> Data {
        if let error = mockError {
            throw error
        }
        return mockData ?? Data()
    }
    
    func requestJSON(_ endpoint: APIEndpoint, body: [String: Any]?) async throws -> [String: Any] {
        if let error = mockError {
            throw error
        }
        guard let data = mockData,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.noData
        }
        return json
    }
}
#endif
