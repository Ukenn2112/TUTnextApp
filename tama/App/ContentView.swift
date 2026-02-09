import SwiftUI

/// アプリのルートコンテンツビュー
/// ログイン状態に応じてLoginViewまたはメインタブビューを表示する
struct ContentView: View {

    // MARK: - プロパティ

    @State private var selectedTab = 1
    @State private var isLoggedIn = false
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var ratingService: RatingService

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
            NotificationCenter.default.publisher(for: AppDelegate.handleURLSchemeNotification)
        ) { notification in
            if let url = notification.object as? URL {
                handleDeepLink(url: url)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("NavigateToPageFromNotification"))
        ) { notification in
            if let page = notification.userInfo?["page"] as? String {
                navigateToTab(for: page)
            }
        }
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    // MARK: - サブビュー

    /// メインタブビュー（ログイン後に表示）
    private var mainTabView: some View {
        VStack(spacing: 0) {
            HeaderView(selectedTab: $selectedTab, isLoggedIn: $isLoggedIn)

            TabView(selection: $selectedTab) {
                BusScheduleView()
                    .tag(0)
                TimetableView(isLoggedIn: $isLoggedIn)
                    .tag(1)
                AssignmentView(isLoggedIn: $isLoggedIn)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.bottom)

            TabBarView(selectedTab: $selectedTab)
        }
    }

    // MARK: - プライベートメソッド

    /// ログイン状態を確認する
    private func checkLoginStatus() {
        let user = UserService.shared.getCurrentUser()
        isLoggedIn = user != nil
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
            name: Notification.Name("BusParametersFromURL"),
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
