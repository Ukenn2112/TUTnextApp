import Foundation

// MARK: - Data Extensions

extension Data {
    /// Initialize Data from a hex string
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert Data to hex string
    func toHexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - String Extensions

extension String {
    /// Trim and encode for URL
    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    /// Check if string is empty or whitespace only
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Truncate string to specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
    
    /// Initialize String from hex
    init?(hex: String) {
        guard let data = Data(hexString: hex) else {
            return nil
        }
        self.init(data: data, encoding: .utf8)
    }
}

// MARK: - Date Extensions

extension Date {
    /// ISO8601 formatter
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Short date formatter
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Medium date formatter
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Time only formatter
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Full date and time formatter
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// End of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// Format to short date string
    func shortDate() -> String {
        Date.shortDate.string(from: self)
    }
    
    /// Format to medium date string
    func mediumDate() -> String {
        Date.mediumDate.string(from: self)
    }
    
    /// Format to time string
    func timeOnly() -> String {
        Date.timeOnly.string(from: self)
    }
    
    /// Relative date string (Today, Yesterday, etc.)
    func relativeDate() -> String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        if isTomorrow { return "Tomorrow" }
        return mediumDate()
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// Safe subscript that returns nil for out-of-bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Result Extensions

extension Result {
    /// Get value or throw
    func get() throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    /// Return nil if string is empty
    var nilIfEmpty: String? {
        switch self {
        case .some(let str) where !str.isEmpty:
            return str
        default:
            return nil
        }
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    /// Merge with another dictionary
    func merged(with other: [Key: Value]) -> [Key: Value] {
        var result = self
        for (key, value) in other {
            result[key] = value
        }
        return result
    }
}
