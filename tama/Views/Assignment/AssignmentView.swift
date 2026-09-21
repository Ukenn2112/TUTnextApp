import SwiftUI

// MARK: - レイアウト定数

/// 課題ページの共通のレイアウト値
enum AssignmentLayout {
    /// ページ内容の列の横の余白。
    /// 課題カードと横スクロールのフィルター行が同じ線に揃うように、
    /// どちらもこの値を使う（`.padding(.horizontal)` の既定値と同じ）
    static let horizontalPadding: CGFloat = 16

    /// 4ptを基本にした1本だけの余白の目盛り。
    /// カードの間隔はすべてこの段から選び、ビューに数値を直接書かない
    enum Spacing {

        /// 8pt
        static let xs: CGFloat = 8

        /// 16pt（カードとカードの間・ページの横の余白）
        static let m: CGFloat = 16
    }

    /// 1列のときのカードとカードの縦の間隔
    static let cardSpacing = Spacing.m

    /// 2列のときのカードどうしの間（縦も横も同じ値）。
    /// カードの輪郭は枠で取るので隣り合う影を気にする必要がなく、
    /// 1列のときと同じページ共通の間隔にして、他のページと同じ密度に揃える
    static let gridSpacing = Spacing.m
}

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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // フォアグラウンド復帰通知オブザーバー
    @State private var willEnterForegroundObserver: NSObjectProtocol?
    /// ページに与えられている大きさ（2列にするかの判定に使う）
    @State private var containerSize: CGSize = .zero
    /// 折り目が有効なときの2つの列の幅（平らなときは nil＝等幅）
    @State private var columnSplit: DuoColumnSplit?

    /// 縦バーのポーズで、ページ内タイトルの下に空ける余白
    private static let verticalBarTitleBottomSpacing: CGFloat = 8

    enum AssignmentFilter {
        case all, today, thisWeek, thisMonth, overdue
    }

    var body: some View {
        ZStack {
            // ページの地はどの画面も同じ白（暗い外観では黒）。
            // 課題カードはこの上に、アプリ共通の1ptの枠だけで輪郭を取って並べる
            CardSurface.pageFill
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
        // セーフエリアを無視した後の大きさ＝このポーズでのページの実寸を読む
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
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
                        .padding(.horizontal, AssignmentLayout.horizontalPadding)
                        .padding(.vertical, 5)
                    }
                    .clippedToHorizontalSafeArea(contentInset: AssignmentLayout.horizontalPadding)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))

                    // 課題リスト
                    ScrollView {
                        if isTwoPane {
                            twoColumnGrid
                        } else {
                            LazyVStack(spacing: AssignmentLayout.cardSpacing) {
                                ForEach(filteredAssignments) { assignment in
                                    card(for: assignment)
                                        .padding(.horizontal, AssignmentLayout.horizontalPadding)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    // 折り目はスクロールしない入れ物（＝このスクロールビューの枠）の座標で読む
                    .onGeometryChange(for: DuoColumnSplit?.self) { proxy in
                        DuoColumnSplit.make(
                            proxy: proxy, padding: AssignmentLayout.horizontalPadding)
                    } action: { columnSplit = $0 }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 課題カード1枚（1列でも2列でも同じ部品・同じ動き）
    private func card(for assignment: Assignment) -> some View {
        AssignmentCardView(assignment: assignment) {
            if let url = URL(string: assignment.url) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - 2列のグリッド

    /// 課題カードを左右に並べるかどうか（判定は時間割タブ・バスタブと同じ `DuoTwoPane`）
    private var isTwoPane: Bool {
        DuoTwoPane.isEnabled(
            containerSize: containerSize, horizontalSizeClass: horizontalSizeClass)
    }

    /// 2列のグリッド。
    ///
    /// 読む順は左→右→次の行。同じ行のカードは上端で揃え、高さは中身なりにする
    /// （引き伸ばして高さを合わせると、短い課題のカードに空白が溜まってしまう）。
    /// 折りたたんでいないときは等幅、折り目が有効なときは左右の領域そのものの幅にして、
    /// 列と列の間（＝折り目の帯とその余白）にはカードを1枚も置かない
    private var twoColumnGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: AssignmentLayout.gridSpacing) {
            ForEach(filteredAssignments) { assignment in
                card(for: assignment)
            }
        }
        .padding(.horizontal, AssignmentLayout.horizontalPadding)
        .padding(.vertical)
    }

    /// 2つの列（HIGに従い、折り目が列と列の間に落ちるよう必ず偶数の列にする）
    private var gridColumns: [GridItem] {
        guard let columnSplit else {
            return Array(
                repeating: GridItem(
                    .flexible(), spacing: AssignmentLayout.gridSpacing, alignment: .top),
                count: 2)
        }
        return [
            GridItem(.fixed(columnSplit.leadingWidth), spacing: columnSplit.gutter, alignment: .top),
            GridItem(.fixed(columnSplit.trailingWidth), spacing: 0, alignment: .top)
        ]
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
