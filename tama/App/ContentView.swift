import SwiftUI

/// アプリのルートコンテンツビュー
/// ログイン状態に応じてLoginViewまたはメインタブビューを表示する
struct ContentView: View {

    // MARK: - プロパティ

    @State private var selectedTab = 1
    @State private var isLoggedIn = false
    @State private var assignmentCount: Int = 0

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
    }

    // MARK: - サブビュー

    /// メインタブビュー（ログイン後に表示）
    private var mainTabView: some View {
        VStack(spacing: 0) {
            HeaderView(selectedTab: $selectedTab, isLoggedIn: $isLoggedIn)

            TabView(selection: $selectedTab) {
                BusScheduleView()
                    .tabItem {
                        Label(NSLocalizedString("バス", comment: "タブバー"), systemImage: "bus")
                    }
                    .tag(0)

                TimetableView(isLoggedIn: $isLoggedIn)
                    .tabItem {
                        Label(NSLocalizedString("時間割", comment: "タブバー"), systemImage: "calendar")
                    }
                    .tag(1)

                AssignmentView(isLoggedIn: $isLoggedIn)
                    .tabItem {
                        Label(NSLocalizedString("課題", comment: "タブバー"), systemImage: "pencil.line")
                    }
                    .badge(assignmentCount)
                    .tag(2)

                Color.clear
                    .tabItem {
                        Label(NSLocalizedString("その他", comment: "タブバー"), systemImage: "ellipsis.circle")
                    }
                    .tag(3)
            }
            .tint(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 3 {
                    selectedTab = oldValue
                }
            }
        }
        .overlay(alignment: .bottom) {
            moreMenuOverlay
        }
        .onAppear {
            fetchAssignmentCount()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .assignmentsUpdated)
        ) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                assignmentCount = count
            }
        }
    }

    /// タブバー上の「その他」メニューオーバーレイ
    private var moreMenuOverlay: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Color.clear
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity)
            }
            MoreMenuButton {
                Color.clear
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 50)
    }

    // MARK: - プライベートメソッド

    /// ログイン状態を確認する
    private func checkLoginStatus() {
        let user = UserService.shared.getCurrentUser()
        isLoggedIn = user != nil
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
            selectedTab = 1
        case "assignment":
            selectedTab = 2
        case "bus":
            selectedTab = 0
            sendBusParameters()
        case "print":
            presentPrintSystemView()
        default:
            break
        }
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

    /// 印刷システム画面をモーダルで表示する
    private func presentPrintSystemView() {
        let printSystemView = PrintSystemView.handleURLScheme()

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootController = scene.windows.first?.rootViewController
        else {
            return
        }

        let hostingController = UIHostingController(rootView: printSystemView)
        rootController.present(hostingController, animated: true)
    }
}

// MARK: - プレビュー

#Preview {
    ContentView()
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(RatingService.shared)
}
