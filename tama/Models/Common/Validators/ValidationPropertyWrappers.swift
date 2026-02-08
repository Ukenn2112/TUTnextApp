import Foundation

/// Property wrapper for minimum string length validation
@propertyWrapper
public struct MinLength: Codable, Equatable {
    public let minLength: Int
    public var wrappedValue: String
    
    public init(minLength: Int, wrappedValue: String) {
        self.minLength = minLength
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        wrappedValue.count >= minLength
    }
    
    public func validate() -> Bool {
        wrappedValue.count >= minLength
    }
}

/// Property wrapper for maximum string length validation
@propertyWrapper
public struct MaxLength: Codable, Equatable {
    public let maxLength: Int
    public var wrappedValue: String
    
    public init(maxLength: Int, wrappedValue: String) {
        self.maxLength = maxLength
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        wrappedValue.count <= maxLength
    }
    
    public func validate() -> Bool {
        wrappedValue.count <= maxLength
    }
}

/// Property wrapper for email validation
@propertyWrapper
public struct Email: Codable, Equatable {
    public var wrappedValue: String
    
    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: wrappedValue)
    }
    
    public func validate() -> Bool {
        projectedValue
    }
}

/// Property wrapper for non-empty string validation
@propertyWrapper
public struct NonEmpty: Codable, Equatable {
    public var wrappedValue: String
    
    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        !wrappedValue.isEmpty
    }
    
    public func validate() -> Bool {
        projectedValue
    }
}

/// Property wrapper for positive integer validation
@propertyWrapper
public struct Positive: Codable, Equatable {
    public var wrappedValue: Int
    
    public init(wrappedValue: Int) {
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        wrappedValue >= 0
    }
    
    public func validate() -> Bool {
        projectedValue
    }
}

/// Property wrapper for range validation
@propertyWrapper
public struct InRange<T: Comparable>: Codable, Equatable {
    public let min: T
    public let max: T
    public var wrappedValue: T
    
    public init(min: T, max: T, wrappedValue: T) {
        self.min = min
        self.max = max
        self.wrappedValue = wrappedValue
    }
    
    public var projectedValue: Bool {
        wrappedValue >= min && wrappedValue <= max
    }
    
    public func validate() -> Bool {
        projectedValue
    }
}
