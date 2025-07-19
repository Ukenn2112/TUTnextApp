import SwiftUI

struct HeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var oauthService: GoogleOAuthService
    @Binding var selectedTab: Int
    @Binding var isLoggedIn: Bool
    @State private var showingUserSettings = false
    @State private var user: User?
    @State private var showSafariView = false
    @State private var keijiBoardURL: URL?
    @State private var semester: Semester = .current  // 使用当前学期数据
    @State private var showRevokeConfirmation = false  // 取消授权确认对话框

    // NotificationCenterを使用してUserDefaultsの変更を監視
    private let userDefaultsObserver = NotificationCenter.default
        .publisher(for: UserDefaults.didChangeNotification)

    // ビュー表示時にユーザー情報を読み込む
    var body: some View {
        HStack(spacing: 8) {
            // 标题区域
            currentTitle

            Spacer()

            // 右侧按钮
            HStack(spacing: 16) {
                // 掲示板
                Button(action: { showSafariView = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)

                        // 未読通知バッジ
                        if let unreadCount = user?.allKeijiMidokCnt, unreadCount > 0 {
                            let displayText = unreadCount > 99 ? "99+" : "\(unreadCount)"

                            Text(displayText)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(
                                            color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .offset(x: -10, y: 14)
                                .animation(.spring(), value: unreadCount)
                        }
                    }
                }
                .offset(y: -2)

                // 用户头像
                Button(action: { showingUserSettings = true }) {
                    Text(getInitials())
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .sheet(
            isPresented: $showSafariView,
            onDismiss: {
                // シートが閉じられた時（下スワイプでも）に実行される
                NotificationCenter.default.post(name: .announcementSafariDismissed, object: nil)
            }
        ) {
            // 掲示板SafariViewが閉じられた時も通知を送信するように修正
            SafariWebView(
                url: createKeijiBoardURL() ?? URL(
                    string: "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml")!,
                dismissNotification: .announcementSafariDismissed
            )
        }
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(isLoggedIn: $isLoggedIn)
        }
        .sheet(
            isPresented: $oauthService.showOAuthWebView,
            onDismiss: {
                // OAuth WebViewが閉じられた時の処理
                oauthService.cancelOAuth()
                NotificationCenter.default.post(name: .googleOAuthWebViewDismissed, object: nil)
            }
        ) {
            // Google OAuth WebView
            if let url = oauthService.oauthURL {
                SafariWebView(
                    url: url,
                    dismissNotification: .googleOAuthWebViewDismissed
                )
            }
        }
        .onAppear {
            // ビュー表示時にUserServiceからユーザー情報を取得
            loadUserData()
            // TimetableServiceから学期情報を取得
            semester = TimetableService.shared.currentSemester
        }
        .onReceive(userDefaultsObserver) { _ in
            // UserDefaultsが変更されたときにユーザー情報を再読み込み
            loadUserData()
        }
        .onReceive(TimetableService.shared.$currentSemester) { updatedSemester in
            // 学期情報が更新されたときに反映
            semester = updatedSemester
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthSuccess)) { _ in
            // OAuth成功時の処理
            print("Google OAuth 授权成功")
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthError)) { notification in
            // OAuth失败时的处理
            if let error = notification.userInfo?["error"] as? String {
                print("Google OAuth 授权失败: \(error)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthWebViewDismissed)) { _ in
            // OAuth WebView关闭时的处理
            print("Google OAuth WebView 已关闭")
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthCallbackReceived)) { _ in
            // OAuth回调收到时立即关闭WebView
            print("Google OAuth 回调已收到，强制关闭WebView")
            oauthService.showOAuthWebView = false
        }
        .alert(NSLocalizedString("認証取り消し確認", comment: "取消授权确认对话框标题"), isPresented: $showRevokeConfirmation) {
            Button(NSLocalizedString("キャンセル", comment: "取消按钮"), role: .cancel) { }
            Button(NSLocalizedString("認証取り消し", comment: "确认取消按钮"), role: .destructive) {
                oauthService.clearAuthorization()
            }
        } message: {
            Text(NSLocalizedString("認証を取り消しますか？\n取り消し後は Classroom の課題が表示されなくなります。", comment: "取消授权确认消息"))
        }
    }

    // 掲示板URLを生成する関数
    private func createKeijiBoardURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "funcId": "Bsd507",
            "autoLoginAuthCd": "",
            "formId": "Bsd50701",
            "encryptedPassword": encryptedPassword,
            "userId": user.username,
            "parameterMap": "",
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        // カスタムエンコーディング
        let customEncoded =
            jsonString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "'", with: "%27")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: ",", with: "%2C")
            .replacingOccurrences(of: "/", with: "%2F")
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ";", with: "%3B")
            .replacingOccurrences(of: "=", with: "%3D")
            .replacingOccurrences(of: "?", with: "%3F")
            .replacingOccurrences(of: "{", with: "%7B")
            .replacingOccurrences(of: "}", with: "%7D")

        let encodedLoginInfo =
            customEncoded
            .replacingOccurrences(of: "%2522", with: "%22")
            .replacingOccurrences(of: "%255C", with: "%5C")

        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }

    // ユーザーデータを読み込む
    private func loadUserData() {
        // UserDefaultsから直接データを取得して最新の状態を確保
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
            let updatedUser = try? JSONDecoder().decode(User.self, from: userData)
        {
            // 前回と異なる場合のみ更新（特に未読通知数が変わった場合）
            if user?.allKeijiMidokCnt != updatedUser.allKeijiMidokCnt {
                print("未読通知数が更新されました: \(updatedUser.allKeijiMidokCnt ?? 0)")
                user = updatedUser
            } else if user == nil {
                user = updatedUser
            }
        } else {
            // UserServiceからも取得を試みる
            user = UserService.shared.getCurrentUser()
        }
    }

    // 获取当前标题
    private var currentTitle: some View {
        Group {
            if selectedTab == 1 {
                HStack(spacing: 4) {
                    Text(semester.shortYearString)
                        .font(.system(size: 15, weight: .bold))
                        .padding(6)
                        .background(Color.pink.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .cornerRadius(10)

                    Text(semester.fullDisplayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
            } else if selectedTab == 2 {
                HStack(spacing: 12) {
                    Text(getTitleText())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Google OAuth授权按钮
                    OAuthButton()
                }
                .padding(.horizontal, 10)
            } else {
                Text(getTitleText())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
            }
        }
    }
    
    // OAuth授权按钮组件
    private func OAuthButton() -> some View {
        Button(action: {
            if oauthService.isAuthorized {
                // 已授权状态下显示取消授权确认对话框
                showRevokeConfirmation = true
            } else {
                // 未授权时开始OAuth流程
                oauthService.startOAuth()
            }
        }) {
            HStack(spacing: 4) {
                if oauthService.isAuthorizing && !oauthService.showOAuthWebView {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if oauthService.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 12))
                }
                
                Text(getOAuthButtonText())
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(getOAuthButtonColor())
            )
        }
        .disabled(oauthService.isAuthorizing && !oauthService.showOAuthWebView)
        .animation(.easeInOut(duration: 0.2), value: oauthService.isAuthorized)
        .animation(.easeInOut(duration: 0.2), value: oauthService.isAuthorizing)
        .animation(.easeInOut(duration: 0.2), value: oauthService.showOAuthWebView)
    }
    
    private func getOAuthButtonText() -> String {
        if oauthService.showOAuthWebView {
            return NSLocalizedString("認証中", comment: "认证中")
        } else if oauthService.isAuthorized {
            return NSLocalizedString("認証済み", comment: "已授权")
        } else {
            return NSLocalizedString("Classroom 認証", comment: "Classroom 授权")
        }
    }
    
    private func getOAuthButtonColor() -> Color {
        if oauthService.showOAuthWebView {
            return Color.orange
        } else if oauthService.isAuthorized {
            return Color.green
        } else {
            return Color.blue
        }
    }

    private func getTitleText() -> String {
        switch selectedTab {
        case 0: return NSLocalizedString("スクールバス", comment: "顶部tab")
        case 2: return NSLocalizedString("课题", comment: "顶部tab")
        default: return ""
        }
    }

    // イニシャルを取得（名前の頭文字、最大2文字）
    private func getInitials() -> String {
        guard let fullName = user?.fullName else { return "?" }

        // 空白で分割して最初の部分を取得
        let nameParts = fullName.split(separator: "　")
        if let firstPart = nameParts.first {
            // 最初の部分から最大2文字を取得
            let initialChars = String(firstPart.prefix(2))
            return initialChars
        }

        return "?"
    }
}

#Preview {
    HeaderView(selectedTab: .constant(1), isLoggedIn: .constant(true))
}
