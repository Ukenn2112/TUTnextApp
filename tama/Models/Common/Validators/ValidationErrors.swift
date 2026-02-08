import Foundation

/// Validation error types
public enum ValidationError: LocalizedError, Equatable {
    case minLength(field: String, minLength: Int, actual: Int)
    case maxLength(field: String, maxLength: Int, actual: Int)
    case email(field: String, value: String)
    case nonEmpty(field: String)
    case positive(field: String, value: Int)
    case range(field: String, min: Any, max: Any, value: Any)
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
        case .range(let field, let min, let max, let value):
            return "\(field) must be between \(min) and \(max) (actual: \(value))"
        case .custom(let message):
            return message
        }
    }
}

/// Protocol for validatable models
public protocol Validatable {
    func validate() throws
}

/// Extension for validating Codable models with property wrappers
public extension Validatable where Self: Codable {
    func validate() throws {
        let mirror = Mirror(reflecting: self)
        
        for case let (label?, value) in mirror.children {
            switch value {
            case let wrapper as MinLength:
                if !wrapper.validate() {
                    throw ValidationError.minLength(
                        field: label,
                        minLength: wrapper.minLength,
                        actual: wrapper.wrappedValue.count
                    )
                }
            case let wrapper as MaxLength:
                if !wrapper.validate() {
                    throw ValidationError.maxLength(
                        field: label,
                        maxLength: wrapper.maxLength,
                        actual: wrapper.wrappedValue.count
                    )
                }
            case let wrapper as Email:
                if !wrapper.validate() {
                    throw ValidationError.email(field: label, value: wrapper.wrappedValue)
                }
            case let wrapper as NonEmpty:
                if !wrapper.validate() {
                    throw ValidationError.nonEmpty(field: label)
                }
            case let wrapper as Positive:
                if !wrapper.validate() {
                    throw ValidationError.positive(field: label, value: wrapper.wrappedValue)
                }
            default:
                break
            }
        }
    }
}

/// Type-erased validator container
public struct AnyValidator<T> {
    private let _validate: (T) throws -> Void
    
    public init(_ validate: @escaping (T) throws -> Void) {
        self._validate = validate
    }
    
    public func validate(_ value: T) throws {
        try _validate(value)
    }
}

/// Composite validator that combines multiple validators
public struct CompositeValidator<T>: Validatable {
    private let validators: [(T) throws -> Void]
    
    public init(_ validators: [(T) throws -> Void]) {
        self.validators = validators
    }
    
    public func validate(_ value: T) throws {
        for validator in validators {
            try validator(value)
        }
    }
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
    
    /// Validate string length range
    public static func validateLength(
        _ value: String,
        min: Int?,
        max: Int?,
        fieldName: String
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let minLength = min, trimmed.count < minLength {
            throw ValidationError.minLength(field: fieldName, minLength: minLength, actual: trimmed.count)
        }
        
        if let maxLength = max, trimmed.count > maxLength {
            throw ValidationError.maxLength(field: fieldName, maxLength: maxLength, actual: trimmed.count)
        }
        
        return trimmed
    }
}
