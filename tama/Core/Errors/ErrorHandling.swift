import Foundation

// MARK: - Result Type

typealias Result<T> = Swift.Result<T, Error>

// MARK: - Async Result Type

typealias AsyncResult<T> = async -> T

// MARK: - Result Helper

enum ResultHelper {
    static func success<T>(_ value: T) -> Result<T> {
        .success(value)
    }
    
    static func failure<T>(_ error: Error) -> Result<T> {
        .failure(error)
    }
    
    static func tryMap<T, U>(_ transform: (T) throws -> U) -> (Result<T>) -> Result<U> {
        { result in
            switch result {
            case .success(let value):
                return .success(try transform(value))
            case .failure(let error):
                return .failure(error)
            }
        }
    }
}

// MARK: - Error Handler

final class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let apiError = error as? APIError {
            return .api(apiError)
        }
        
        if let authError = error as? AuthError {
            return .auth(AuthErrorType.invalidCredentials)
        }
        
        if let decodingError = error as? DecodingError {
            return .decoding(decodingError)
        }
        
        return .unknown(error.localizedDescription ?? "Unknown error occurred")
    }
    
    func log(_ error: Error, file: String = #file, line: Int = #line) {
        let appError = handle(error)
        print("[\(file):\(line)] Error (\(appError.severity)): \(appError.localizedDescription ?? "")")
    }
}

// MARK: - Error Display Helper

struct ErrorDisplayHelper {
    static func title(for error: Error) -> String {
        let appError = ErrorHandler.shared.handle(error)
        return appError.localizedDescription ?? "Error"
    }
    
    static func message(for error: Error) -> String {
        let appError = ErrorHandler.shared.handle(error)
        return appError.localizedDescription ?? "An unexpected error occurred"
    }
    
    static func suggestion(for error: Error) -> String {
        let appError = ErrorHandler.shared.handle(error)
        return appError.recoverySuggestion ?? "Please try again"
    }
}
