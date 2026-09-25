import SwiftUI

/// アプリのルートコンテンツビュー
/// ログイン状態に応じてLoginViewまたはメインタブビューを表示する
struct ContentView: View {

    // MARK: - プロパティ

    @State private var selectedTab = 1
    /// ログイン済みか。起動時の値は `init()` で保存済みのユーザーから決める
    /// （先にログイン画面を1フレーム描いてからクロスフェードで切り替わるのを防ぐ）
    @State private var isLoggedIn: Bool
    @State private var assignmentCount: Int = 0
    @State private var isMoreMode = false
    @State private var isMoreDialogPresented = false
    @State private var activeMenuSheet: MoreMenuSheet?
    /// 時間割タブのタイトルに使う学期（システムツールバーのタイトルとして表示する）
    @State private var semester: Semester = .current
    /// システムのバーが縦バーとして表示されているか（Duoの外側ディスプレイ・内側横向き・Split View）。
    ///
    /// タイトルの描き方（バーの先頭の項目／ページ内容の先頭）はこの値で切り替わるため、
    /// 判定はここ一箇所だけで行い、各タブのツールバーとページ内容へ同じ値を渡す。
    /// 起動直後の数フレームは判定できないため、横バーと同じ表示から始める
    @State private var isVerticalBarPose = false
    /// Classroom認証の取り消し確認を出すかどうか（課題タブのツールバー項目から立てられる）
    @State private var showRevokeConfirmation = false
    @EnvironmentObject private var oauthService: GoogleOAuthService
    @Environment(\.scenePhase) private var scenePhase

    /// 「その他」タブの値
    private static let moreTab = 3

    /// メインタブの値
    private static let mainTabs = [0, 1, 2]

    /// 「その他」モード専用の追加タブの値
    private static let extraTabs = [4, 5]

    /// タブバーの差し替えがUIKit側に反映されるまで、アニメーションを止めておく時間
    private static let tabSwapSettleTime: TimeInterval = 0.1

    /// 表示中のシートを閉じてから、別のシートを開き直すまで待つ時間
    private static let sheetSwapSettleTime: TimeInterval = 0.4

    /// アニメーション抑止の世代番号（連続して切り替えた場合に、古いタイマーが途中で抑止を解除しないようにする）
    private static var animationSuppressionToken = 0

    /// タブバー自体を差し替える方式を使うかどうか。
    /// 独立表示（prominentロール）が使えるiOS 27以降のみ対応し、それ未満は確認ダイアログで表示する
    private static var usesSwappableTabBar: Bool {
        if #available(iOS 27.0, *) { true } else { false }
    }

    #if DEBUG
    /// 起動引数（UserDefaultsの同名キーでも可）で指定された初期タブ。
    ///
    /// `-DuoInitialTab bus|timetable|assignment` を付けて起動すると、そのタブを選んだ状態で始まる。
    /// `simctl openurl` によるディープリンクはシステムの確認ダイアログが出てCLIから抜けられないため、
    /// ポーズごとのスクリーンショットをタブ別に撮るための検証用の入口
    private static var debugInitialTab: Int? {
        switch UserDefaults.standard.string(forKey: "DuoInitialTab") {
        case "bus": return 0
        case "timetable": return 1
        case "assignment": return 2
        default: return nil
        }
    }
    #endif

    // MARK: - 初期化

    init() {
        _isLoggedIn = State(initialValue: UserService.shared.getCurrentUser() != nil)
    }

    // MARK: - ボディ

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
                    .transition(.opacity)
            } else {
                mainTabView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoggedIn)
        .onChange(of: isLoggedIn) {
            // ログアウト・セッション切れ後に「その他」モードやシートの状態を持ち越さない
            resetMoreMenuState()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                resetMoreMenuState()
            }
        }
        .onAppear {
            checkLoginStatus()
            processInitialURL()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .handleURLScheme)
        ) { notification in
            if let url = notification.object as? URL {
                handleDeepLink(url: url)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .navigateToPageFromNotification)
        ) { notification in
            if let page = notification.userInfo?["page"] as? String {
                navigateToTab(for: page)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .sessionExpired)
        ) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
        }
    }

    // MARK: - サブビュー

    /// メインタブビュー（ログイン後に表示）
    private var mainTabView: some View {
        tabView
            .tint(.appPrimary)
            .sensoryFeedback(.selection, trigger: isMoreMode)
            .sheet(item: $activeMenuSheet) { sheet in
                sheet.content
            }
            // Google OAuthのWebViewはアプリ全体で1つ。
            // 共通ツールバー（`mainToolbar`）はタブごとに生成されるため、
            // 共有シングルトンの状態に紐づくこのシートは必ずここ（タブの外側）で1回だけ出す
            .sheet(
                isPresented: $oauthService.showOAuthWebView,
                onDismiss: {
                    // OAuth WebViewが閉じられた時の処理
                    oauthService.cancelOAuth()
                    NotificationCenter.default.post(name: .googleOAuthWebViewDismissed, object: nil)
                }
            ) {
                if let url = oauthService.oauthURL {
                    SafariWebView(
                        url: url,
                        dismissNotification: .googleOAuthWebViewDismissed
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .googleOAuthCallbackReceived)
            ) { _ in
                // OAuthコールバック受信時にWebViewを閉じる
                oauthService.showOAuthWebView = false
            }
            .onChange(of: selectedTab) {
                // 通常は select(tab:) で同時に解除されるが、念のためのセーフティネット
                setMoreMode(false)
            }
            .onAppear {
                fetchAssignmentCount()
                #if DEBUG
                if let tab = Self.debugInitialTab {
                    selectedTab = tab
                }
                #endif
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .assignmentsUpdated)
            ) { notification in
                if let count = notification.userInfo?["count"] as? Int {
                    assignmentCount = count
                }
            }
            .onReceive(TimetableService.shared.$currentSemester) { updatedSemester in
                semester = updatedSemester
            }
            .onVerticalBarEdgeChange { isVerticalBar in
                guard isVerticalBarPose != isVerticalBar else { return }
                // 起動直後は必ず「縦バーではない」から切り替わるため、アニメーションを付けない
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isVerticalBarPose = isVerticalBar
                }
            }
    }

    // MARK: - プライベートメソッド

    /// ログイン状態を確認する。
    /// 起動時の値は `init()` で決めてあるため、ここでは念のための再確認として、
    /// 差があってもアニメーションなしで反映する（ログイン・ログアウト操作によるフェードとは区別する）
    private func checkLoginStatus() {
        let isUserStored = UserService.shared.getCurrentUser() != nil
        guard isUserStored != isLoggedIn else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isLoggedIn = isUserStored
        }
    }

    /// 課題数を取得する
    private func fetchAssignmentCount() {
        AssignmentService.shared.getAssignments { result in
            switch result {
            case .success(let assignments):
                self.assignmentCount = assignments.count
            case .failure:
                self.assignmentCount = 0
            }
        }
    }

    /// アプリ起動時に初期URLを処理する
    private func processInitialURL() {
        guard let path = AppDelegate.shared.getPathComponent(),
              isLoggedIn
        else {
            return
        }
        navigateToTab(for: path)
        AppDelegate.shared.resetURLProcessing()
    }

    /// URLスキームのディープリンクを処理する
    private func handleDeepLink(url: URL) {
        guard isLoggedIn else { return }
        let path = url.host ?? ""
        navigateToTab(for: path)
    }

    /// パスに基づいて適切なタブに遷移する
    private func navigateToTab(for path: String) {
        switch path {
        case "timetable":
            select(tab: 1)
        case "assignment":
            select(tab: 2)
        case "bus":
            select(tab: 0)
            sendBusParameters()
        case "print":
            presentPrintSystemSheet()
        default:
            break
        }
    }

    /// メインタブへ遷移する（「その他」モード中であれば同じ更新の中で解除する）
    private func select(tab: Int) {
        isMoreDialogPresented = false
        setMoreMode(false, selecting: tab)
    }

    /// バスパラメータをBusScheduleViewに送信する
    private func sendBusParameters() {
        let route = AppDelegate.shared.getQueryValue(for: "route")
        let schedule = AppDelegate.shared.getQueryValue(for: "schedule")

        guard route != nil || schedule != nil else { return }

        let userInfo: [String: Any?] = ["route": route, "schedule": schedule]
        NotificationCenter.default.post(
            name: .busParametersFromURL,
            object: nil,
            userInfo: userInfo as [AnyHashable: Any]
        )
    }

    /// 印刷システム画面をシートで表示する。
    ///
    /// 共有ファイルはPrintSystemViewModelの初期化時に読み込まれるため、既にシートを表示中の場合は
    /// 一度閉じてから開き直して、上書きされた共有ファイルを取り込み直す。
    /// 表示状態の更新を次のループに回すのは、起動直後のディープリンクでも
    /// ログイン状態の反映（`resetMoreMenuState()`）に打ち消されないようにするため
    private func presentPrintSystemSheet() {
        let settleTime: TimeInterval = activeMenuSheet == nil ? 0 : Self.sheetSwapSettleTime
        activeMenuSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) {
            activeMenuSheet = MoreMenuItem.printSystem.makeSheet()
        }
    }
}

// MARK: - タブのコンテンツ

extension ContentView {

    /// 課題タブのコンテンツ。
    /// 共通のツールバー項目に加えて、Classroom認証のボタンを先頭に置く。
    /// 取り消し確認のアラートは、項目がオーバーフローメニューへ送られても確実に出せるようここでホストする
    private var assignmentTabContent: some View {
        let title = NSLocalizedString("課題", comment: "ヘッダータイトル")

        return NavigationStack {
            probed("assignment") {
                AssignmentView(
                    isLoggedIn: $isLoggedIn,
                    title: title,
                    isVerticalBarPose: isVerticalBarPose
                )
            }
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .mainToolbar(
                    title: title,
                    isVerticalBarPose: isVerticalBarPose,
                    isLoggedIn: $isLoggedIn
                ) {
                    ClassroomAuthToolbarButton(showRevokeConfirmation: $showRevokeConfirmation)
                }
                .alert(
                    NSLocalizedString("認証取り消し確認", comment: "認証取り消し確認ダイアログタイトル"),
                    isPresented: $showRevokeConfirmation
                ) {
                    Button(NSLocalizedString("キャンセル", comment: "キャンセルボタン"), role: .cancel) { }
                    Button(
                        NSLocalizedString("認証取り消し", comment: "認証取り消しボタン"),
                        role: .destructive
                    ) {
                        oauthService.clearAuthorization()
                    }
                } message: {
                    Text(
                        NSLocalizedString(
                            "認証を取り消しますか？\n取り消し後は Classroom の課題が表示されなくなります。",
                            comment: "認証取り消し確認メッセージ"
                        )
                    )
                }
        }
    }

    /// バスタブのコンテンツ。
    /// システムのナビゲーションバー（Duoでは縦バー）にタイトルと共通ツールバー項目を載せる
    private var busTabContent: some View {
        let title = NSLocalizedString("スクールバス", comment: "ヘッダータイトル")

        return NavigationStack {
            probed("bus") {
                BusScheduleView(title: title, isVerticalBarPose: isVerticalBarPose)
            }
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .mainToolbar(
                    title: title,
                    isVerticalBarPose: isVerticalBarPose,
                    isLoggedIn: $isLoggedIn
                )
        }
    }

    /// 時間割タブのコンテンツ。
    /// システムのナビゲーションバー（Duoでは縦バー）にタイトルと共通ツールバー項目を載せる
    private var timetableTabContent: some View {
        let title = semester.fullDisplayName

        return NavigationStack {
            probed("timetable") {
                TimetableView(
                    isLoggedIn: $isLoggedIn,
                    title: title,
                    isVerticalBarPose: isVerticalBarPose,
                    // 「今日」ペインのバスからバスタブへ。
                    // （タブの選択はここが持っているため、通知ではなく直接渡す）
                    // 路線の切り替えは `tama://bus?route=` と同じ道（`busParametersFromURL`）を通す
                    onOpenBus: { route in
                        select(tab: 0)
                        NotificationCenter.default.post(
                            name: .busParametersFromURL,
                            object: nil,
                            userInfo: ["route": route.rawValue]
                        )
                    },
                    // 「今日」ペインの「課題をすべて見る」から課題タブへ
                    onOpenAssignments: { select(tab: 2) }
                )
            }
                // タイトルは横バーではバーの先頭の項目として、縦バーではページ内容の先頭に描く。
                // navigationTitle は見た目としては使わないが、アクセシビリティのために設定しておく
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .mainToolbar(
                    title: title,
                    isVerticalBarPose: isVerticalBarPose,
                    isLoggedIn: $isLoggedIn
                )
        }
    }

    /// タブのコンテンツに計測用プローブを付ける（DEBUGビルドかつ起動引数が指定されたときのみ動作する）
    private func probed<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        #if DEBUG
        return content().duoMetricsProbe(label)
        #else
        return content()
        #endif
    }
}

// MARK: - タブビュー

extension ContentView {

    /// タブビュー本体
    @ViewBuilder private var tabView: some View {
        if #available(iOS 27.0, *) {
            TabView(selection: tabSelection) {
                // 選択中のタブを隠すとUIKit側でクラッシュするため、メインタブは隠さずラベルとロールだけを差し替える
                Tab(
                    tabTitle(0, main: NSLocalizedString("バス", comment: "タブバー")),
                    systemImage: tabImage(0, main: "bus"),
                    value: 0,
                    role: tabRole(0)
                ) {
                    busTabContent
                }

                Tab(
                    tabTitle(1, main: NSLocalizedString("時間割", comment: "タブバー")),
                    systemImage: tabImage(1, main: "calendar"),
                    value: 1,
                    role: tabRole(1)
                ) {
                    timetableTabContent
                }

                Tab(
                    tabTitle(2, main: NSLocalizedString("課題", comment: "タブバー")),
                    systemImage: tabImage(2, main: "pencil.line"),
                    value: 2,
                    role: tabRole(2)
                ) {
                    assignmentTabContent
                }
                .badge(isMoreMode ? 0 : assignmentCount)

                // 「その他」モード専用の追加枠（選択されることはないため隠しても安全）
                ForEach(Self.extraTabs, id: \.self) { tab in
                    Tab(tabTitle(tab, main: ""), systemImage: tabImage(tab, main: "ellipsis"), value: tab) {
                        Color.clear
                    }
                    .hidden(!isMoreMode)
                }

                // 「その他」モードへ切り替えるボタン（選択されることはない）
                Tab(
                    NSLocalizedString("その他", comment: "タブバー"),
                    systemImage: "ellipsis",
                    value: Self.moreTab,
                    role: tabRole(Self.moreTab)
                ) {
                    Color.clear
                }
                .hidden(isMoreMode)
            }
        } else {
            legacyTabView
        }
    }

    /// iOS 26以前向けのタブビュー（タブバーの独立表示ができないため、その他の機能は確認ダイアログで表示）
    private var legacyTabView: some View {
        TabView(selection: tabSelection) {
            busTabContent
                .tabItem {
                    Label(NSLocalizedString("バス", comment: "タブバー"), systemImage: "bus")
                }
                .tag(0)

            timetableTabContent
                .tabItem {
                    Label(NSLocalizedString("時間割", comment: "タブバー"), systemImage: "calendar")
                }
                .tag(1)

            assignmentTabContent
                .tabItem {
                    Label(NSLocalizedString("課題", comment: "タブバー"), systemImage: "pencil.line")
                }
                .badge(assignmentCount)
                .tag(2)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("その他", comment: "タブバー"), systemImage: "ellipsis")
                }
                .tag(Self.moreTab)
        }
        .confirmationDialog(
            NSLocalizedString("その他", comment: "タブバー"),
            isPresented: $isMoreDialogPresented
        ) {
            ForEach(MoreMenuItem.allCases) { item in
                Button(item.title) {
                    activeMenuSheet = item.makeSheet()
                }
            }
        }
    }

    /// TabViewの選択バインディング。
    /// 選択状態になるのはメインタブのみで、コンテンツは「その他」モード中も切り替わらない
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == Self.moreTab {
                    if Self.usesSwappableTabBar {
                        setMoreMode(true)
                    } else {
                        isMoreDialogPresented = true
                    }
                } else if !isMoreMode {
                    selectedTab = newValue
                } else if newValue == selectedTab {
                    // 「その他」モード中は選択中のタブが「その他」ボタンの役割を引き継いでいる
                    setMoreMode(false)
                } else {
                    // 切り替え直後のタップでも、シートはアニメーション付きで表示する
                    endUIKitAnimationSuppression()
                    activeMenuSheet = moreItem(forTab: newValue)?.makeSheet()
                }
            }
        )
    }

    /// タブのタイトル（「その他」モード中は差し替える）。`main` にはローカライズ済みの文字列を渡す
    private func tabTitle(_ tab: Int, main: String) -> String {
        guard isMoreMode else { return main }
        if tab == selectedTab {
            return NSLocalizedString("その他", comment: "タブバー")
        }
        return moreItem(forTab: tab)?.title ?? ""
    }

    /// タブのアイコン（「その他」モード中は差し替える）
    private func tabImage(_ tab: Int, main: String) -> String {
        guard isMoreMode else { return main }
        if tab == selectedTab {
            return "ellipsis"
        }
        return moreItem(forTab: tab)?.systemImage ?? main
    }

    /// タブバー右側に独立表示するタブのロール。
    /// 通常時は「その他」タブが、「その他」モード中は選択中のタブが同じ見た目で独立表示されるため、
    /// 「その他」ボタンがハイライトされたように見える。
    /// （iOS 27では検索フィールドを持たない search ロールのタブは独立表示されないため、prominent を使う）
    @available(iOS 27.0, *)
    private func tabRole(_ tab: Int) -> TabRole? {
        let prominentTab = isMoreMode ? selectedTab : Self.moreTab
        return tab == prominentTab ? .prominent : nil
    }
}

// MARK: - 「その他」モード

extension ContentView {

    /// 「その他」モードを切り替える。`tab` を指定すると、同じ更新の中でそのメインタブを選択する。
    ///
    /// タブの増減やロールの移動をシステムがアニメーションすると表示が乱れる（選択インジケーターが
    /// カプセルの外へ滑り出る、隣のタブが一瞬ハイライトされる等）ため、アニメーションなしで切り替える。
    /// SwiftUIはロール変更のアニメーション有無を指定できず、UIKitへの反映も状態変更の後になるため、
    /// 反映が終わるまでの短時間だけUIKit側のアニメーションも止めている
    private func setMoreMode(_ isOn: Bool, selecting tab: Int? = nil) {
        guard isOn != isMoreMode else {
            if let tab {
                selectedTab = tab
            }
            return
        }

        suppressUIKitAnimations(for: Self.tabSwapSettleTime)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isMoreMode = isOn
            if let tab {
                selectedTab = tab
            }
        }
    }

    /// 「その他」メニュー関連の状態を初期化する
    private func resetMoreMenuState() {
        setMoreMode(false)
        isMoreDialogPresented = false
        activeMenuSheet = nil
    }

    /// 「その他」モード中にタブへ割り当てられる項目。
    /// 選択中のタブ（「その他」ボタンの役割を引き継ぐ）を除いた残りのタブに、並び順で割り当てる
    private func moreItem(forTab tab: Int) -> MoreMenuItem? {
        let slots = (Self.mainTabs + Self.extraTabs).filter { $0 != selectedTab }
        guard let index = slots.firstIndex(of: tab), MoreMenuItem.allCases.indices.contains(index) else {
            return nil
        }
        return MoreMenuItem.allCases[index]
    }

    /// UIKit側のアニメーションを止め、`duration` が過ぎたら戻す。
    /// 途中で別の抑止が始まった場合は、古いタイマーでは戻さず新しいタイマーに任せる
    private func suppressUIKitAnimations(for duration: TimeInterval) {
        Self.animationSuppressionToken += 1
        let token = Self.animationSuppressionToken
        UIView.setAnimationsEnabled(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if token == Self.animationSuppressionToken {
                UIView.setAnimationsEnabled(true)
            }
        }
    }

    /// 抑止中でもすぐにUIKit側のアニメーションを戻す。
    /// 世代番号を進めて、残っているタイマーが後から状態を触らないようにする
    private func endUIKitAnimationSuppression() {
        Self.animationSuppressionToken += 1
        UIView.setAnimationsEnabled(true)
    }
}

// MARK: - プレビュー

#Preview {
    ContentView()
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(RatingService.shared)
        .environmentObject(GoogleOAuthService.shared)
}
