import SwiftUI

struct AssignmentView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var viewModel = AssignmentViewModel()
    @State private var selectedFilter: AssignmentFilter = .all
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var ratingService: RatingService
    @EnvironmentObject private var oauthService: GoogleOAuthService
    // 前台通知观察者
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil

    enum AssignmentFilter {
        case all, today, thisWeek, thisMonth, overdue
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("読み込み中...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("エラーが発生しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button {
                        viewModel.loadAssignments()
                    } label: {
                        Text("再読み込み")
                    }
                }
                .padding()
            } else if viewModel.assignments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("課題はありません")
                        .font(.title2)

                    Text("現在提出すべき課題はありません。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        viewModel.loadAssignments()
                    } label: {
                        Text("再読み込み")
                    }
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // フィルターセグメントコントロール
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            filterButton(title: NSLocalizedString("すべて", comment: ""), filter: .all)
                            filterButton(
                                title: NSLocalizedString("今日", comment: ""), filter: .today)
                            filterButton(
                                title: NSLocalizedString("今週", comment: ""), filter: .thisWeek)
                            filterButton(
                                title: NSLocalizedString("今月", comment: ""), filter: .thisMonth)
                            filterButton(
                                title: NSLocalizedString("期限切れ", comment: ""), filter: .overdue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    }
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))

                    // 課題リスト
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredAssignments) { assignment in
                                AssignmentCardView(assignment: assignment) {
                                    if let url = URL(string: assignment.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadAssignments()
            // 課題表示の重要イベントを記録
            ratingService.recordSignificantEvent()
            
            // Google OAuth認証状態をチェック
            Task {
                await oauthService.loadAuthorizationStatus()
            }
            
            // 应用程序从后台恢复时刷新页面
            willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [self] _ in
                print("AssignmentView: アプリがフォアグラウンドに復帰しました")
                viewModel.loadAssignments()
                // フォアグラウンド復帰時にも認証状態をチェック
                Task {
                    await oauthService.loadAuthorizationStatus()
                }
            }
        }
        .onDisappear {
            // 移除通知观察者
            if let observer = willEnterForegroundObserver {
                NotificationCenter.default.removeObserver(observer)
                willEnterForegroundObserver = nil
            }
        }
    }

    private var filteredAssignments: [Assignment] {
        switch selectedFilter {
        case .all:
            return viewModel.assignments
        case .today:
            return viewModel.todayAssignments
        case .thisWeek:
            return viewModel.thisWeekAssignments
        case .thisMonth:
            return viewModel.thisMonthAssignments
        case .overdue:
            return viewModel.overdueAssignments
        }
    }

    private func filterButton(title: String, filter: AssignmentFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            selectedFilter == filter
                                ? Color.blue.opacity(0.9)
                                : Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15)
                        )
                        .shadow(
                            color: selectedFilter == filter ? Color.blue.opacity(0.3) : Color.clear,
                            radius: 3, x: 0, y: 2)
                )
                .foregroundColor(selectedFilter == filter ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Assignment View") {
    NavigationView {
        AssignmentView(isLoggedIn: .constant(true))
    }
}
