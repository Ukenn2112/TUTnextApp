import Combine
import Foundation
import SwiftUI

/// 課題一覧ViewModel
///
/// 課題そのものは `AssignmentStore` が1つだけ控えている（時間割タブの「今日」ペインと共用）。
/// ここはその控えを写して、課題タブの絞り込みと残り時間の更新だけを受け持つ
@MainActor
final class AssignmentViewModel: ObservableObject {
    @Published var assignments: [Assignment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let store = AssignmentStore.shared
    private var cancellables: Set<AnyCancellable> = []

    // タイマーを使って残り時間を更新
    nonisolated(unsafe) private var timer: Timer?

    init() {
        setupTimer()
        bindStore()
    }

    /// 共用の控えを写す（`assign(to:on:)` は自分を強く持ってしまうので `sink` を使う）
    private func bindStore() {
        store.$assignments
            .sink { [weak self] in self?.assignments = $0 }
            .store(in: &cancellables)
        store.$isLoading
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)
        store.$errorMessage
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
        timer = nil
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

    /// 課題一覧を取り直す（プレビュー・モック・ちらつき防止の扱いは `AssignmentStore` が持つ）
    func loadAssignments() {
        store.reload()
    }

    // 期限切れの課題をフィルタリング
    var overdueAssignments: [Assignment] {
        return assignments.filter { $0.isOverdue && $0.isPending }
            .sorted { $0.dueDate > $1.dueDate }  // 期限切れは新しい順（より最近期限切れになったもの順）
    }

    // 今日期限の課題をフィルタリング
    var todayAssignments: [Assignment] {
        let calendar = Calendar.current
        return assignments.filter { assignment in
            !assignment.isOverdue && assignment.isPending
                && calendar.isDateInToday(assignment.dueDate)
        }.sorted { $0.dueDate < $1.dueDate }  // 時間順
    }

    // 今週期限の課題をフィルタリング（今日を除く）
    var thisWeekAssignments: [Assignment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        return assignments.filter { assignment in
            !assignment.isOverdue && assignment.isPending
                && !calendar.isDateInToday(assignment.dueDate) && assignment.dueDate <= endOfWeek
        }.sorted { $0.dueDate < $1.dueDate }  // 日付順
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
            !assignment.isOverdue && assignment.isPending && assignment.dueDate > endOfWeek
                && assignment.dueDate <= endOfMonth
        }.sorted { $0.dueDate < $1.dueDate }  // 日付順
    }

    // 課題の詳細ページを開く
    func openAssignmentURL(_ assignment: Assignment) {
        if let url = URL(string: assignment.url) {
            UIApplication.shared.open(url)
        }
    }
}
