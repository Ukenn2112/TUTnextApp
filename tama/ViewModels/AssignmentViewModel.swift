//
//  AssignmentViewModel.swift
//  TUTnext
//
//  MVVM Assignment ViewModel with async/await
//

import Foundation
import Combine

@MainActor
class AssignmentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var assignments: [Assignment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let assignmentService: AssignmentService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(assignmentService: AssignmentService = .shared) {
        self.assignmentService = assignmentService
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        assignmentService.$assignments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] assignments in
                self?.assignments = assignments
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadAssignments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await assignmentService.fetchAssignments()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func refresh() async {
        await loadAssignments()
    }
    
    // MARK: - Computed Properties
    var todayAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return dueDate >= today && dueDate < tomorrow
        }
    }
    
    var thisWeekAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return dueDate >= today && dueDate < weekFromNow
        }
    }
    
    var thisMonthAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthFromNow = calendar.date(byAdding: .month, value: 1, to: today)!
        
        return assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return dueDate >= today && dueDate < monthFromNow
        }
    }
    
    var overdueAssignments: [Assignment] {
        let today = Calendar.current.startOfDay(for: Date())
        
        return assignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return dueDate < today
        }
    }
}
