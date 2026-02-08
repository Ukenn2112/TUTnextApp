import Foundation

// MARK: - App Error

enum AppError: Error, LocalizedError, Identifiable {
    case network(NetworkError)
    case auth(AuthErrorType)
    case validation(ValidationError)
    case api(APIError)
    case decoding(DecodingError)
    case unknown(String)
    
    var id: String {
        errorDescription ?? "unknown"
    }
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .auth(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .api(let error):
            return error.localizedDescription
        case .decoding(let error):
            return error.localizedDescription
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(let error):
            return error.recoverySuggestion
        case .auth(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .api(let error):
            return error.recoverySuggestion
        case .decoding:
            return "Please try again or contact support"
        case .unknown:
            return "Please try again"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .network:
            return .warning
        case .auth:
            return .critical
        case .validation:
            return .info
        case .api:
            return .warning
        case .decoding:
            return .warning
        case .unknown:
            return .error
        }
    }
}

// MARK: - Error Types

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case unreachable
    case sslError
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unreachable:
            return "Server unreachable"
        case .sslError:
            return "Secure connection failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again"
        case .timeout:
            return "The server is taking too long to respond. Please try again"
        case .unreachable:
            return "The server is currently unavailable. Please try again later"
        case .sslError:
            return "There may be a security issue. Please contact support"
        }
    }
}

enum AuthErrorType: LocalizedError {
    case invalidCredentials
    case sessionExpired
    case unauthorized
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .sessionExpired:
            return "Your session has expired"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .tokenRefreshFailed:
            return "Failed to refresh your session"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your credentials and try again"
        case .sessionExpired:
            return "Please log in again"
        case .unauthorized:
            return "Please log in with the correct account"
        case .tokenRefreshFailed:
            return "Please log out and log in again"
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyField(field: String)
    case invalidFormat(field: String)
    case passwordTooShort
    case invalidEmail
    case valueOutOfRange(field: String, min: Int, max: Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) is required"
        case .invalidFormat(let field):
            return "\(field) format is invalid"
        case .passwordTooShort:
            return "Password must be at least 8 characters"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .valueOutOfRange(let field, let min, let max):
            return "\(field) must be between \(min) and \(max)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyField, .invalidFormat, .invalidEmail, .passwordTooShort:
            return "Please enter a valid value"
        case .valueOutOfRange:
            return "Please enter a value within the valid range"
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3
    
    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
