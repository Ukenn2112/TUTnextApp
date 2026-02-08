// MARK: - View Protocols
// This file contains view-related protocols for the TUTnext app

import Foundation
import SwiftUI

// MARK: - InputViewProtocol

/// Protocol for views that accept user input
protocol InputViewProtocol {
    var isValid: Bool { get }
    func validate() -> Bool
}

// MARK: - ListViewProtocol

/// Protocol for list-based views
protocol ListViewProtocol {
    associatedtype Item
    var items: [Item] { get set }
    var isEmpty: Bool { get }
    func refresh() async
}

// MARK: - DetailViewProtocol

/// Protocol for detail views
protocol DetailViewProtocol {
    associatedtype Item
    var item: Item? { get set }
    func loadItem(id: String) async throws
}

// MARK: - FormViewProtocol

/// Protocol for form views
protocol FormViewProtocol {
    var isSubmitEnabled: Bool { get }
    var errors: [String: String] { get set }
    func submit() async throws -> Bool
}

// MARK: - FilterableViewProtocol

/// Protocol for views with filtering capability
protocol FilterableViewProtocol {
    associatedtype FilterType
    var filter: FilterType? { get set }
    var isFiltered: Bool { get }
    func applyFilter(_ filter: FilterType)
    func clearFilter()
}

// MARK: - SearchableViewProtocol

/// Protocol for views with search functionality
protocol SearchableViewProtocol {
    var searchText: String { get set }
    var isSearching: Bool { get }
    var filteredItems: [Self.Item] { get }
    func performSearch(_ query: String)
    func clearSearch()
}

// MARK: - PaginatedViewProtocol

/// Protocol for views with pagination
protocol PaginatedViewProtocol {
    var page: Int { get set }
    var hasMorePages: Bool { get set }
    var isLoadingMore: Bool { get set }
    func loadMore() async
    func resetPagination()
}

// MARK: - RefreshableViewProtocol

/// Protocol for views with pull-to-refresh
protocol RefreshableViewProtocol {
    var isRefreshing: Bool { get set }
    func refresh() async
}

// MARK: - ErrorDisplayable

/// Protocol for views that display errors
protocol ErrorDisplayable {
    var displayedError: Error? { get set }
    func showError(_ error: Error)
    func clearError()
}

// MARK: - LoadingDisplayable

/// Protocol for views that show loading state
protocol LoadingDisplayable {
    var isLoading: Bool { get set }
    func showLoading()
    func hideLoading()
}

// MARK: - EmptyStateDisplayable

/// Protocol for views that show empty state
protocol EmptyStateDisplayable {
    var isEmpty: Bool { get }
    var emptyTitle: String { get }
    var emptyMessage: String { get }
    var emptyAction: (() -> Void)? { get }
}

// MARK: - AsyncViewModel

/// Base class for async view models
@MainActor
class AsyncViewModel<State> {
    @Published private(set) var state: State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    init(initialState: State) {
        self.state = initialState
    }
    
    @MainActor
    func withLoading<T>(_ operation: () async throws -> T) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await operation()
        } catch {
            self.error = error
            throw error
        }
    }
}
