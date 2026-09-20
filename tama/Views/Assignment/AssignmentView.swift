import SwiftUI

struct AssignmentView: View {
    @Binding var isLoggedIn: Bool
    /// ページのタイトル（システムのナビゲーションタイトルと同じ値）。
    /// 縦バーのポーズではバーのタイトルを消して、この文字列をページ内容の先頭に描く
    let title: String
    /// システムのバーが縦バーとして表示されているか（判定は `ContentView` が一箇所で行う）
    let isVerticalBarPose: Bool
    @StateObject private var viewModel = AssignmentViewModel()
    @State private var selectedFilter: AssignmentFilter = .all
    @EnvironmentObject private var ratingService: RatingService
    @EnvironmentObject private var oauthService: GoogleOAuthService
    // フォアグラウンド復帰通知オブザーバー
    @State private var willEnterForegroundObserver: NSObjectProtocol?

    /// 縦バーのポーズで、ページ内タイトルの下に空ける余白
    private static let verticalBarTitleBottomSpacing: CGFloat = 8

    enum AssignmentFilter {
        case all, today, thisWeek, thisMonth, overdue
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isVerticalBarPose {
                    // 縦バーのポーズではバーのタイトル帯を無視して上を詰め、
                    // グリフ上端がウィンドウ上端から VerticalBarLayout.edgeMargin の位置に来るように描く
                    VerticalBarPageTitle(title: title)
                        .padding(.bottom, Self.verticalBarTitleBottomSpacing)
                }

                contentView
            }
        }
        // 縦バーのポーズでは空のナビゲーションバー帯の分だけ上が空くため、ウィンドウ上端まで広げる。
        // 下端はスクロールする内容なのでシステムに任せる（横バーのポーズでは何もしない）
        .ignoresSafeArea(.container, edges: isVerticalBarPose ? .top : [])
        .onAppear {
            viewModel.loadAssignments()
            // 課題表示の重要イベントを記録
            ratingService.recordSignificantEvent()

            // Google OAuth認証状態をチェック
            Task {
                await oauthService.loadAuthorizationStatus()
            }

            // アプリがフォアグラウンドに復帰した時にページを更新
            willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    print("AssignmentView: アプリがフォアグラウンドに復帰しました")
                    viewModel.loadAssignments()
                    // フォアグラウンド復帰時にも認証状態をチェック
                    await oauthService.loadAuthorizationStatus()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthSuccess)) { _ in
            // Google OAuth認証成功時に課題リストを更新
            print("AssignmentView: Google OAuth認証成功、課題リストを更新")
            viewModel.loadAssignments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthStatusChanged)) { _ in
            // Google OAuthステータス変化時に課題リストを更新（認証取り消しを含む）
            print("AssignmentView: Google OAuthステータス変化、課題リストを更新")
            viewModel.loadAssignments()
        }
        .onDisappear {
            // 通知オブザーバーを削除
            if let observer = willEnterForegroundObserver {
                NotificationCenter.default.removeObserver(observer)
                willEnterForegroundObserver = nil
            }
        }
    }

    // MARK: - サブビュー

    /// タイトルの下に置く本体（読み込み中・エラー・空・課題リスト）
    @ViewBuilder private var contentView: some View {
        Group {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                : Color(UIColor.secondarySystemFill)
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
    AssignmentViewPreviewHost()
        .environmentObject(RatingService.shared)
        .environmentObject(GoogleOAuthService.shared)
}

private struct AssignmentViewPreviewHost: View {
    @State private var selectedTab = 2
    @State private var isLoggedIn = true
    @State private var showRevokeConfirmation = false

    private let title = NSLocalizedString("課題", comment: "ヘッダータイトル")

    var body: some View {
        TabView(selection: $selectedTab) {
            Color.clear
                .tabItem {
                    Label(NSLocalizedString("バス", comment: "タブバー"), systemImage: "bus")
                }
                .tag(0)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("時間割", comment: "タブバー"), systemImage: "calendar")
                }
                .tag(1)

            NavigationStack {
                AssignmentView(isLoggedIn: $isLoggedIn, title: title, isVerticalBarPose: false)
                    .navigationTitle(title)
                    .toolbarTitleDisplayMode(.inline)
                    .mainToolbar(title: title, isVerticalBarPose: false, isLoggedIn: $isLoggedIn) {
                        ClassroomAuthToolbarButton(showRevokeConfirmation: $showRevokeConfirmation)
                    }
            }
            .tabItem {
                Label(NSLocalizedString("課題", comment: "タブバー"), systemImage: "pencil.line")
            }
            .badge(Assignment.previewAssignments.count)
            .tag(2)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("その他", comment: "タブバー"), systemImage: "ellipsis.circle")
                }
                .tag(3)
        }
        .tint(.appPrimary)
    }
}
