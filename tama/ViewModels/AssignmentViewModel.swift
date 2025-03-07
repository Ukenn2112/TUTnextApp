import Foundation
import SwiftUI

class AssignmentViewModel: ObservableObject {
    @Published var assignments: [Assignment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let assignmentService = AssignmentService.shared
    
    // タイマーを使って残り時間を更新
    private var timer: Timer?
    
    init() {
        setupTimer()
    }
    
    deinit {
        invalidateTimer()
    }
    
    private func setupTimer() {
        // 既存のタイマーを無効化
        invalidateTimer()
        
        // 1分ごとに残り時間を更新するタイマーを設定
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        
        // タイマーをメインループに追加
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func loadAssignments() {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        // 開発環境ではモックデータを使用
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.assignments = self.assignmentService.getMockAssignments()
            self.isLoading = false
        }
        #else
        // 本番環境では実際のAPIを呼び出す
        assignmentService.getAssignments { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let assignments):
                    self.assignments = assignments
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        #endif
    }
    
    // 期限切れの課題をフィルタリング
    var overdueAssignments: [Assignment] {
        return assignments.filter { $0.isOverdue && $0.isPending }
    }
    
    // 今日期限の課題をフィルタリング
    var todayAssignments: [Assignment] {
        let calendar = Calendar.current
        return assignments.filter { assignment in
            !assignment.isOverdue && 
            assignment.isPending && 
            calendar.isDateInToday(assignment.dueDate)
        }
    }
    
    // 今週期限の課題をフィルタリング（今日を除く）
    var thisWeekAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return assignments.filter { assignment in
            !assignment.isOverdue && 
            assignment.isPending && 
            !calendar.isDateInToday(assignment.dueDate) &&
            assignment.dueDate <= endOfWeek
        }
    }
    
    // 今月期限の課題をフィルタリング（今週を除く）
    var thisMonthAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        
        // 今月の最終日を取得
        let components = calendar.dateComponents([.year, .month], from: today)
        let startOfMonth = calendar.date(from: components)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        
        return assignments.filter { assignment in
            !assignment.isOverdue && 
            assignment.isPending && 
            assignment.dueDate > endOfWeek &&
            assignment.dueDate <= endOfMonth
        }
    }
    
    // 課題の詳細ページを開く
    func openAssignmentURL(_ assignment: Assignment) {
        if let url = URL(string: assignment.url) {
            UIApplication.shared.open(url)
        }
    }
} 