import Foundation
import UIKit

// MARK: - View Protocol

/// Protocol for SwiftUI views
@MainActor
protocol ViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
    func showSuccess(_ message: String)
}

// MARK: - ViewModel Protocol

/// Base protocol for ViewModels
protocol ViewModelProtocol: AnyObject {
    associatedtype State
    var state: State { get }
    func updateState(_ newState: State)
}

// MARK: - Service Protocol

/// Base protocol for services
protocol ServiceProtocol {
    var isInitialized: Bool { get }
    func initialize()
}

// MARK: - Coordinator Protocol

/// Protocol for navigation coordinators
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController? { get set }
    var childCoordinators: [Coordinator] { get set }
    
    func start()
    func addChild(_ coordinator: Coordinator)
    func removeChild(_ coordinator: Coordinator)
}

// MARK: - Network Service Protocol

/// Protocol for network-dependent services
protocol NetworkDependent {
    var isNetworkAvailable: Bool { get }
    func handleNetworkUnavailability()
}

// MARK: - Observable ViewModel

/// Base class for observable ViewModels
@MainActor
class ObservableViewModel<State> {
    @Published private(set) var state: State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    init(initialState: State) {
        self.state = initialState
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ error: Error?) {
        self.error = error
    }
    
    func updateState(_ newState: State) {
        state = newState
    }
}

// MARK: - Debouncer

/// Utility for debouncing operations
final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        if let workItem = workItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - Throttler

/// Utility for throttling operations
final class Throttler {
    private let delay: TimeInterval
    private var lastExecutionTime: Date?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func throttle(action: () -> Void) {
        let now = Date()
        if let lastTime = lastExecutionTime {
            guard now.timeIntervalSince(lastTime) >= delay else { return }
        }
        lastExecutionTime = now
        action()
    }
}
