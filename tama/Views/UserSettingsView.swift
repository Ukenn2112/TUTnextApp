import SwiftUI
import SafariServices
import MessageUI

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoggedIn: Bool
    @State private var user: User?
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var languageService: LanguageService
    @State private var showSafari: Bool = false
    @State private var urlToOpen: URL? = nil
    @State private var showMailComposer: Bool = false
    @State private var showingDarkModeSheet = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // ユーザー情報セクション
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                // プロフィール画像（イニシャルアバター）
                                Text(getInitials())
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.red.opacity(colorScheme == .dark ? 0.8 : 1))
                                    .clipShape(Circle())
                                
                                // ユーザー情報
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(user?.fullName ?? "ユーザー名")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("@\(user?.username ?? "username")")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                        }
                        .padding(.bottom, 12)
                        
                        // 設定セクション
                        VStack(spacing: 0) {
                            // アカウント設定
                            SettingsSectionHeader(title: NSLocalizedString("アカウント設定", comment: ""))
                            
                            SettingsRow(icon: "lock.fill", title: NSLocalizedString("パスワード変更", comment: "")) {
                                openPasswordChangeURL()
                            }
                            
                            // アプリ設定
                            SettingsSectionHeader(title: NSLocalizedString("アプリ設定", comment: ""))
                            
                            Button(action: {
                                handleNotificationSettings()
                            }) {
                                HStack {
                                    Image(systemName: notificationService.isAuthorized ? "bell.fill" : "bell.slash")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 20))
                                        .frame(width: 24, height: 24)
                                    
                                    Text("通知設定")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                    
                                    // 通知状態を表示
                                    Text(getNotificationStatusText())
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                languageService.openLanguageSettings()
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 20))
                                        .frame(width: 24, height: 24)
                                    
                                    Text("言語")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                    
                                    Text(languageService.currentLanguage)
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { showingDarkModeSheet = true }) {
                                HStack {
                                    Image(systemName: "moon.fill")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 20))
                                        .frame(width: 24, height: 24)
                                    
                                    Text("ダークモード")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                    
                                    Text(getDarkModeText())
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // サポート
                            SettingsSectionHeader(title: NSLocalizedString("その他", comment: ""))

                            // 利用規約
                            SettingsRow(icon: "doc.text.fill", title: NSLocalizedString("利用規約", comment: "")) {
                                urlToOpen = URL(string: "https://tama.qaq.tw/user-agreement")!
                                showSafari = true
                            }
                            
                            SettingsRow(icon: "exclamationmark.bubble.fill", title: NSLocalizedString("フィードバック", comment: "")) {
                                sendFeedback()
                            }
                            
                            // ログアウト
                            Button(action: {
                                logout()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.square.fill")
                                        .foregroundColor(colorScheme == .dark ? .red.opacity(0.8) : .red)
                                        .font(.system(size: 20))
                                        .frame(width: 24, height: 24)
                                    
                                    Text("ログアウト")
                                        .foregroundColor(colorScheme == .dark ? .red.opacity(0.8) : .red)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }
                        }
                        
                        // アプリ情報
                        VStack(spacing: 8) {
                            Text("TUTnext")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("バージョン \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 50)
                        
                        // 画面下部の余白を埋めるためのスペーサー
                        Spacer(minLength: UIScreen.main.bounds.height * 0.1)
                    }
                }
            }
            .navigationBarTitle("設定", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            })
            .onAppear {
                loadUserData()
                // 通知権限の状態を確認
                notificationService.checkAuthorizationStatus()
                
                // 通知センターに通知を登録
                NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                    // アプリがアクティブになったときに通知権限を確認
                    print("アプリがアクティブになりました。通知権限を確認します。")
                    self.notificationService.checkAuthorizationStatus()
                }
            }
            .onDisappear {
                // 通知センターから通知を削除
                NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            .sheet(isPresented: $showSafari) {
                if let url = urlToOpen {
                    SafariWebView(url: url)
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(isShowing: $showMailComposer)
            }
            .sheet(isPresented: $showingDarkModeSheet) {
                DarkModeSettingsView(appearanceManager: appearanceManager)
            }
            .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
            .onChange(of: appearanceManager.isDarkMode) { oldValue, newValue in
                print("Settings view updated isDarkMode: \(newValue)")
            }
        }
        .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
    }
    
    // MARK: - Methods
    
    // 通知状態のテキストを取得
    private func getNotificationStatusText() -> String {
        if notificationService.isAuthorized {
            if notificationService.isRegistered {
                return NSLocalizedString("オン", comment: "")
            } else {
                return NSLocalizedString("設定中...", comment: "")
            }
        } else {
            return NSLocalizedString("オフ", comment: "")
        }
    }
    
    // 通知設定の処理
    private func handleNotificationSettings() {
        // 通知の登録状態に基づいて処理を分岐
        if notificationService.isAuthorized && !notificationService.isRegistered {
            // 権限はあるがデバイストークンがない場合は登録処理を実行
            print("リモート通知の登録を開始します")
            notificationService.registerForRemoteNotifications()
        } else {
            // すでに登録処理が行われている場合は設定アプリを開く
            print("設定アプリを開きます")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url) { success in
                    if success {
                        // 設定アプリから戻ってきたときに通知権限を再確認するため、
                        // 少し遅延させて確認する
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            print("設定アプリから戻りました。通知権限を確認します。")
                            self.notificationService.checkAuthorizationStatus()
                        }
                    }
                }
            }
        }
    }
    
    private func getDarkModeText() -> String {
        switch appearanceManager.type {
        case .iSystem:
            return NSLocalizedString("システムに従う", comment: "")
        case .iHight:
            return NSLocalizedString("ライト", comment: "")
        case .iDark:
            return NSLocalizedString("ダーク", comment: "")
        }
    }
    
    // ユーザーデータの読み込み
    private func loadUserData() {
        user = UserService.shared.getCurrentUser()
    }
    
    // ログアウト処理
    private func logout() {
        guard let user = user, let encryptedPassword = user.encryptedPassword else {
            // 暗号化パスワードがない場合はローカルログアウトのみ実行
            performLocalLogout()
            return
        }
        
        // APIを使用してログアウト
        AuthService.shared.logout(userId: user.username, encryptedPassword: encryptedPassword) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // ログアウト成功
                    self.performLocalLogout()
                case .failure(let error):
                    // エラーが発生してもローカルログアウトは実行
                    print("ログアウトAPI呼び出しエラー: \(error.localizedDescription)")
                    self.performLocalLogout()
                }
            }
        }
    }
    
    // ローカルログアウト処理
    private func performLocalLogout() {
        // ユーザーデータをクリア
        UserService.shared.clearCurrentUser()
        
        // 画面を閉じる
        dismiss()
        
        // 少し遅延させてからログイン状態を更新（画面遷移をスムーズにするため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // ログイン状態を更新
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
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
    
    // パスワード変更URLを開く
    private func openPasswordChangeURL() {
        let passwordChangeURL = URL(string: "https://google.tama.ac.jp/unicornidm/user/tama/password/")!
        urlToOpen = passwordChangeURL
        showSafari = true
    }

    // フィードバック送信処理
    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            // メール送信ができない場合の処理
            let emailAddress = "admin@ukenn.top"
            let subject = "TUTnext アプリフィードバック"
            
            if let url = URL(string: "mailto:\(emailAddress)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url)
            }
        }
    }
}

struct DarkModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme // 現在のカラースキームを監視
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // ヘッダーイメージ
                    HStack(spacing: 20) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .light ? .orange : .gray)
                        
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .dark ? .blue : .gray)
                    }
                    .padding(.top, 20)
                    
                    // オプションカード
                    VStack(spacing: 16) {
                        // システム設定に従う
                        appearanceOptionCard(
                            title:  NSLocalizedString("システムに従う", comment: ""),
                            icon: "gear",
                            description: NSLocalizedString("デバイスの設定に合わせて自動的に切り替えます", comment: ""),
                            isSelected: appearanceManager.type == .iSystem,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appearanceManager.type = .iSystem
                                    // システムの場合は現在のシステム設定を反映
                                    let systemIsDark = appearanceManager.getCurrentInterfaceStyle() == .dark
                                    if appearanceManager.isDarkMode != systemIsDark {
                                        appearanceManager.isDarkMode = systemIsDark
                                    }
                                }
                            }
                        )
                        
                        // ライトモード
                        appearanceOptionCard(
                            title: NSLocalizedString("ライトモード", comment: ""),
                            icon: "sun.max.fill",
                            description: NSLocalizedString("明るい外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.type == .iHight,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appearanceManager.type = .iHight
                                    appearanceManager.isDarkMode = false
                                }
                            }
                        )
                        
                        // ダークモード
                        appearanceOptionCard(
                            title: NSLocalizedString("ダークモード", comment: ""),
                            icon: "moon.stars.fill",
                            description: NSLocalizedString("暗い外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.type == .iDark,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    appearanceManager.type = .iDark
                                    appearanceManager.isDarkMode = true
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
            }
            .navigationTitle("外観モード")
            .navigationBarItems(trailing: Button(action: {
                dismiss()
            }) {
                Text("完了")
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            })
            // 状態変更を監視して即座に見た目を更新
            .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
            .onChange(of: appearanceManager.isDarkMode) { oldValue, newValue in
                print("DarkMode sheet updated: \(newValue)")
            }
        }
    }
    
    // カスタムカードビュー
    private func appearanceOptionCard(title: String, icon: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 選択インジケーター
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct SettingsSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGroupedBackground))
    }
}

struct SettingsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.primary)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                    .font(.system(size: 16))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MailComposerView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // メールの件名を設定
        composer.setSubject("TUTnext アプリフィードバック")
        
        // 宛先を設定
        composer.setToRecipients(["admin@ukenn.top"])
        
        // メール本文のテンプレート
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let emailBody = """
        
        
        ------------------------------
        【システム情報】
        アプリバージョン: \(appVersion) (\(buildNumber))
        デバイス: \(deviceModel)
        OS: iOS \(systemVersion)
        ------------------------------
        """
        
        composer.setMessageBody(emailBody, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isShowing = false
        }
    }
}

#Preview {
    UserSettingsView(isLoggedIn: .constant(true))
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(LanguageService.shared)
}
