import Foundation

// MARK: - Service Protocol

protocol ServiceProtocol: AnyObject {
    var isInitialized: Bool { get }
    func initialize()
    func reset()
}

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol {
    func fetch<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func post<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func put<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func delete<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

// MARK: - Repository Protocol

protocol RepositoryProtocol {
    associatedtype Model
    
    func fetchAll() async throws -> [Model]
    func fetch(by id: String) async throws -> Model?
    func create(_ model: Model) async throws -> Model
    func update(_ model: Model) async throws -> Model
    func delete(_ model: Model) async throws
    func delete(by id: String) async throws
}

// MARK: - Cache Protocol

protocol CacheProtocol {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(forKey key: Key) -> Value?
    func set(_ value: Value, forKey key: Key)
    func remove(forKey key: Key)
    func clear()
    func contains(_ key: Key) -> Bool
}

// MARK: - Logger Protocol

protocol LoggerProtocol {
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int)
}

enum LogLevel: String {
    case debug
    case info
    case warning
    case error
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - Analytics Protocol

protocol AnalyticsProtocol {
    func trackEvent(_ event: String, parameters: [String: Any]?)
    func trackScreen(_ screenName: String)
    func setUserProperty(_ property: String, value: Any)
    func logError(_ error: Error, context: [String: Any]?)
}
