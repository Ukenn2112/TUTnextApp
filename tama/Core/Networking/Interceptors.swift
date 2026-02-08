import Foundation

// MARK: - Interceptor Protocol

/// Protocol for request/response interceptors
protocol NetworkInterceptor {
    func intercept(request: URLRequest) -> URLRequest
    func intercept(response: URLResponse, data: Data) -> (URLResponse, Data)
    func intercept(error: AppError, attempt: Int) -> AppError
}

// MARK: - Request Interceptor

/// Interceptor that adds headers to requests
final class RequestInterceptor: NetworkInterceptor {
    private let headers: [String: String]
    
    init(headers: [String: String] = [:]) {
        self.headers = headers
    }
    
    func intercept(request: URLRequest) -> URLRequest {
        var modifiedRequest = request
        for (key, value) in headers {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }
        return modifiedRequest
    }
    
    func intercept(response: URLResponse, data: Data) -> (URLResponse, Data) {
        return (response, data)
    }
    
    func intercept(error: AppError, attempt: Int) -> AppError {
        return error
    }
}

// MARK: - Logging Interceptor

/// Interceptor for logging network requests/responses
final class LoggingInterceptor: NetworkInterceptor {
    private let logTag: String
    private let verbose: Bool
    
    init(logTag: String = "Network", verbose: Bool = false) {
        self.logTag = logTag
        self.verbose = verbose
    }
    
    func intercept(request: URLRequest) -> URLRequest {
        if let url = request.url {
            print("[\(logTag)] Request: \(url.absoluteString)")
        }
        if verbose, let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("[\(logTag)] Request Body: \(bodyString)")
        }
        return request
    }
    
    func intercept(response: URLResponse, data: Data) -> (URLResponse, Data) {
        if let httpResponse = response as? HTTPURLResponse {
            print("[\(logTag)] Response: \(httpResponse.statusCode)")
        }
        if verbose, let responseString = String(data: data, encoding: .utf8) {
            print("[\(logTag)] Response Body: \(responseString)")
        }
        return (response, data)
    }
    
    func intercept(error: AppError, attempt: Int) -> AppError {
        print("[\(logTag)] Error (attempt \(attempt)): \(error.localizedDescription ?? "unknown")")
        return error
    }
}

// MARK: - Interceptor Chain

/// Chain of interceptors that process requests/responses in order
final class InterceptorChain {
    private var interceptors: [NetworkInterceptor] = []
    
    func add(_ interceptor: NetworkInterceptor) {
        interceptors.append(interceptor)
    }
    
    func processRequest(_ request: URLRequest) -> URLRequest {
        var result = request
        for interceptor in interceptors {
            result = interceptor.intercept(request: result)
        }
        return result
    }
    
    func processResponse(_ response: URLResponse, data: Data) -> (URLResponse, Data) {
        var result = (response, data)
        for interceptor in interceptors {
            result = interceptor.intercept(response: result.0, data: result.1)
        }
        return result
    }
    
    func processError(_ error: AppError, attempt: Int) -> AppError {
        var result = error
        for interceptor in interceptors {
            result = interceptor.intercept(error: result, attempt: attempt)
        }
        return result
    }
}
