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

    enum AssignmentFilter: CaseIterable {
        case all, today, thisWeek, thisMonth, overdue

        /// フィルターのチップに出す名前
        var title: String {
            switch self {
            case .all: NSLocalizedString("すべて", comment: "")
            case .today: NSLocalizedString("今日", comment: "")
            case .thisWeek: NSLocalizedString("今週", comment: "")
            case .thisMonth: NSLocalizedString("今月", comment: "")
            case .overdue: NSLocalizedString("期限切れ", comment: "")
            }
        }
    }

    /// タイトルの下の本体に何を出しているか（切り替わりのアニメーションのきっかけにする）
    private enum ContentPhase: Equatable {
        case loading, failure, empty, list
    }

    /// 初回の読み込み中に並べるスケルトンのカード（中身は塗りつぶされて見えない）
    private static let placeholderAssignments = Assignment.placeholderAssignments

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// タイトルの下に置く本体（読み込み中・エラー・空・課題リスト）。
    ///
    /// 取り直しに失敗しても前回の控えが残っていれば、全面のエラーではなく一覧を出したまま
    /// 上に小さな知らせを出す（全面のエラーは、見せる課題が1件も無いときだけ）
    ///
    /// 読み込み中（初回の取得の前だけ）はスケルトンのカードを、空・失敗は下から持ち上げて出す
    private var contentView: some View {
        ZStack {
            switch contentPhase {
            case .loading:
                loadingPlaceholder
                    .motionTransition(.fade)
            case .failure:
                loadFailureView(message: viewModel.errorMessage ?? "")
                    .motionTransition(.rise)
            case .empty:
                emptyView
                    .motionTransition(.rise)
            case .list:
                assignmentList
                    .motionTransition(.fade)
            }
        }
        .motionAnimation(Motion.standard, value: contentPhase)
    }

    private var contentPhase: ContentPhase {
        if viewModel.isLoading {
            return .loading
        } else if viewModel.assignments.isEmpty {
            return viewModel.errorMessage == nil ? .empty : .failure
        } else {
            return .list
        }
    }

    /// 初回の読み込み中のスケルトン。
    ///
    /// キャッシュが無く取得に `Motion.skeletonDelay` より長くかかったときだけ出す
    /// （すぐに取れたときに一瞬だけ塗りつぶしが見えるのを防ぐ）。きらめきは入れ物に1回だけ掛ける
    private var loadingPlaceholder: some View {
        DelayedSkeletonGate(isLoading: true) { showsSkeleton in
            if showsSkeleton {
                ScrollView {
                    cardStack(for: Self.placeholderAssignments)
                }
                .scrollDisabled(true)
                .skeleton(true)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 取得に失敗し、見せる課題も無いとき
    private func loadFailureView(message: String) -> some View {
        ContentUnavailableView {
            Label("エラーが発生しました", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("再読み込み") {
                viewModel.loadAssignments()
            }
        }
    }

    /// 課題が1件も無いとき
    private var emptyView: some View {
        ContentUnavailableView {
            Label {
                Text("課題はありません")
            } icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        } description: {
            Text("現在提出すべき課題はありません。")
        } actions: {
            Button("再読み込み") {
                viewModel.loadAssignments()
            }
        }
    }

    /// 課題の一覧（取り直しの失敗の知らせ・フィルター・カード）
    private var assignmentList: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                refreshFailureNotice(message: errorMessage)
                    .padding(.horizontal, AssignmentLayout.horizontalPadding)
                    .padding(.top, AssignmentLayout.Spacing.xs)
                    .frame(maxWidth: leadingColumnMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .motionTransition(.rise)
            }

            // フィルターのチップ（選択中の塗りがチップの間を滑って移る・選び直すと触覚を返す）。
            // 本のポーズでは左の列（ヒンジの手前）に収め、チップが折り目をまたいでスクロールしないようにする
            ScrollView(.horizontal, showsIndicators: false) {
                SelectionChipRow(AssignmentFilter.allCases, selection: $selectedFilter) { filter in
                    Text(filter.title)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, AssignmentLayout.horizontalPadding)
                .padding(.vertical, 5)
            }
            .clippedToHorizontalSafeArea(contentInset: AssignmentLayout.horizontalPadding)
            .frame(maxWidth: leadingColumnMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))

            // 課題リスト。
            // フィルターを切り替えると、外れたカードは沈みながら消え、入ったカードは持ち上がって現れる
            ScrollView {
                cardStack(for: filteredAssignments)
                    .motionAnimation(Motion.standard, value: selectedFilter)
            }
            // 引っ張って更新（一覧が出ている＝取得済みなので、スケルトンには切り替わらない）
            .refreshable {
                await viewModel.refresh()
            }
            // 折り目はスクロールしない入れ物（＝このスクロールビューの枠）の座標で読む
            .onGeometryChange(for: DuoColumnSplit?.self) { proxy in
                DuoColumnSplit.make(
                    proxy: proxy, padding: AssignmentLayout.horizontalPadding)
            } action: { columnSplit = $0 }
        }
        // 取り直しの失敗の知らせの出入り
        .motionAnimation(Motion.standard, value: viewModel.errorMessage != nil)
    }

    /// カードの並び（1列なら縦に、2つのペインなら2列のグリッドに）。
    /// 課題の一覧と、初回の読み込み中のスケルトンで同じ並べ方を使う
    @ViewBuilder
    private func cardStack(for assignments: [Assignment]) -> some View {
        if isTwoPane {
            twoColumnGrid(for: assignments)
        } else {
            LazyVStack(spacing: AssignmentLayout.cardSpacing) {
                ForEach(assignments) { assignment in
                    card(for: assignment)
                        .padding(.horizontal, AssignmentLayout.horizontalPadding)
                        .motionTransition(.rise)
                }
            }
            .padding(.vertical)
        }
    }

    /// ページの端から左の列の終わり（ヒンジの手前）までの幅。折り目が無効なときは制限しない
    private var leadingColumnMaxWidth: CGFloat {
        columnSplit.map { $0.leadingWidth + AssignmentLayout.horizontalPadding } ?? .infinity
    }

    /// 取り直しに失敗したが、前回の一覧を出し続けているときの小さな知らせ。
    /// バスタブの臨時ダイヤの知らせと同じ、オレンジの枠だけで輪郭を取る体裁
    private func refreshFailureNotice(message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("課題を更新できませんでした")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.loadAssignments()
            } label: {
                Text("再読み込み")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .fill(CardSurface.pageFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .stroke(Color.orange.opacity(0.4), lineWidth: CardSurface.outlineWidth)
        )
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
    private func twoColumnGrid(for assignments: [Assignment]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: AssignmentLayout.gridSpacing) {
            ForEach(assignments) { assignment in
                card(for: assignment)
                    .motionTransition(.rise)
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
