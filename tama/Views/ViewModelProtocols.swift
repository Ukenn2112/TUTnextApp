//
//  ViewModelProtocols.swift
//  TUTnext
//
//  MVVM ViewModel Protocols and Base Classes
//

import Foundation
import Combine

// MARK: - ViewModel Protocol
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    
    var state: State { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
}

// MARK: - Loading State
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }
    
    var error: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Base ViewModel
@MainActor
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasError = false
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
            hasError = false
        }
    }
    
    func setError(_ message: String) {
        errorMessage = message
        hasError = true
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
        hasError = false
    }
    
    func reset() {
        isLoading = false
        errorMessage = nil
        hasError = false
    }
}

// MARK: - Async ViewModel
@MainActor
class AsyncViewModel<T>: BaseViewModel {
    @Published private(set) var data: T?
    @Published var loadingState: LoadingState<T> = .idle
    
    var isLoaded: Bool {
        loadingState != .idle && loadingState.error == nil
    }
    
    func loadData(asyncAction: () async throws -> T) async {
        loadingState = .loading
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await asyncAction()
            self.data = result
            self.loadingState = .loaded(result)
            self.isLoading = false
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.loadingState = .error(message)
            self.isLoading = false
        }
    }
    
    func refresh(asyncAction: () async throws -> T) async {
        loadingState = .loading
        errorMessage = nil
        isLoading = true
        
        do {
            let result = try await asyncAction()
            self.data = result
            self.loadingState = .loaded(result)
            self.isLoading = false
        } catch {
            let message = error.localizedDescription
            self.errorMessage = message
            self.loadingState = .error(message)
            self.isLoading = false
        }
    }
}

// MARK: - Paginated ViewModel
@MainActor
class PaginatedViewModel<T>: AsyncViewModel<[T]> {
    @Published var page = 0
    @Published var hasMorePages = true
    @Published private(set) var items: [T] = []
    
    func loadNextPage(asyncAction: (Int) async throws -> [T]) async {
        guard !isLoading, hasMorePages else { return }
        
        loadingState = .loading
        isLoading = true
        
        do {
            let newItems = try await asyncAction(page)
            
            if newItems.isEmpty {
                hasMorePages = false
            } else {
                items.append(contentsOf: newItems)
                page += 1
            }
            
            data = items
            loadingState = .loaded(items)
            isLoading = false
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            loadingState = .error(message)
            isLoading = false
        }
    }
    
    override func reset() {
        super.reset()
        page = 0
        hasMorePages = true
        items = []
        data = nil
        loadingState = .idle
    }
}
