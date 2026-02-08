import Foundation

/// Validation error types
public enum ValidationError: LocalizedError, Equatable {
    case minLength(field: String, minLength: Int, actual: Int)
    case maxLength(field: String, maxLength: Int, actual: Int)
    case email(field: String, value: String)
    case nonEmpty(field: String)
    case positive(field: String, value: Int)
    case custom(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .minLength(let field, let minLength, let actual):
            return "\(field) must be at least \(minLength) characters (actual: \(actual))"
        case .maxLength(let field, let maxLength, let actual):
            return "\(field) must be at most \(maxLength) characters (actual: \(actual))"
        case .email(let field, let value):
            return "\(field) is not a valid email address: \(value)"
        case .nonEmpty(let field):
            return "\(field) cannot be empty"
        case .positive(let field, let value):
            return "\(field) must be a positive integer (actual: \(value))"
        case .custom(let message):
            return message
        }
    }
}

/// Protocol for validatable models
public protocol Validatable {
    func validate() throws
}

/// Common validation helpers
public enum ValidationHelpers {
    /// Validate that a string is not empty and trim it
    public static func validateAndTrim(_ value: String, fieldName: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.nonEmpty(field: fieldName)
        }
        return trimmed
    }
    
    /// Validate email format
    public static func validateEmail(_ email: String) throws -> String {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard predicate.evaluate(with: email) else {
            throw ValidationError.email(field: "email", value: email)
        }
        return email
    }
}
