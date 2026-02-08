import Foundation
import SwiftUI

// MARK: - View Model Protocol

protocol ViewModelProtocol: AnyObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func send(_ action: Action)
}

// MARK: - View Protocol

protocol ViewProtocol: AnyView {
    associatedtype ViewModel: ViewModelProtocol
    
    var viewModel: ViewModel { get }
    func createView() -> AnyView
}

// MARK: - Loading State

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
    
    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - Alert State

struct AlertState {
    let title: String
    let message: String?
    let primaryButton: AlertButton?
    let secondaryButton: AlertButton?
    
    init(
        title: String,
        message: String? = nil,
        primaryButton: AlertButton? = nil,
        secondaryButton: AlertButton? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
    
    static func confirmation(
        title: String,
        message: String? = nil,
        confirm: @escaping () -> Void,
        cancel: (() -> Void)? = nil
    ) -> AlertState {
        AlertState(
            title: title,
            message: message,
            primaryButton: AlertButton(title: "Confirm", action: confirm),
            secondaryButton: AlertButton(title: "Cancel", action: cancel)
        )
    }
    
    static func alert(
        title: String,
        message: String? = nil,
        dismiss: (() -> Void)? = nil
    ) -> AlertState {
        AlertState(
            title: title,
            message: message,
            primaryButton: AlertButton(title: "OK", action: dismiss)
        )
    }
}

struct AlertButton {
    let title: String
    let action: (() -> Void)?
    let isDestructive: Bool
    
    init(title: String, action: (() -> Void)?, isDestructive: Bool = false) {
        self.title = title
        self.action = action
        self.isDestructive = isDestructive
    }
}

// MARK: - Sheet State

enum SheetState: Identifiable {
    case sheet(AnyView)
    case fullScreenCover(AnyView)
    
    var id: String {
        switch self {
        case .sheet: return "sheet"
        case .fullScreenCover: return "fullScreenCover"
        }
    }
}

// MARK: - Navigation State

struct NavigationState {
    var isActive: Bool = false
    var destination: AnyView?
    
    func navigate(to destination: AnyView) -> NavigationState {
        NavigationState(isActive: true, destination: destination)
    }
    
    mutating func dismiss() {
        isActive = false
        destination = nil
    }
}

// MARK: - Form Validation

protocol FormValidatable {
    var isValid: Bool { get }
    var validationErrors: [String] { get }
}

struct ValidationRule {
    let message: String
    let validate: (String?) -> Bool
    
    static let required = ValidationRule(
        message: "This field is required",
        validate: { $0?.isEmpty == false }
    )
    
    static func email() -> ValidationRule {
        ValidationRule(
            message: "Invalid email format",
            validate: { value in
                guard let value = value, !value.isEmpty else { return true }
                let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
                return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: value)
            }
        )
    }
    
    static func minLength(_ length: Int) -> ValidationRule {
        ValidationRule(
            message: "Minimum \(length) characters required",
            validate: { $0?.count ?? 0 >= length }
        )
    }
}

// MARK: - Identifiable Extension

extension Identifiable {
    var id: Self.ID { self.id }
}
