import SwiftUI
import SafariServices
import MessageUI

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoggedIn: Bool
    @State private var user: User?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSafari: Bool = false
    @State private var urlToOpen: URL? = nil
    @State private var showMailComposer: Bool = false
    
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
                            SettingsSectionHeader(title: "アカウント設定")
                            
                            SettingsRow(icon: "person.fill", title: "スマホサイトへ") {
                                // T-Nextスマホサイトへ
                                if let tnextURL = createTnextURL() {
                                    urlToOpen = tnextURL
                                    showSafari = true
                                }
                            }
                            
                            SettingsRow(icon: "bell.fill", title: "通知設定") {
                                // 通知設定画面へ
                            }
                            
                            SettingsRow(icon: "lock.fill", title: "パスワード変更") {
                                openPasswordChangeURL()
                            }
                            
                            // アプリ設定
                            SettingsSectionHeader(title: "アプリ設定")
                            
                            SettingsRow(icon: "globe", title: "言語") {
                                // 言語設定画面へ
                            }
                            
                            SettingsRow(icon: "moon.fill", title: "ダークモード") {
                                // ダークモード設定
                            }
                            
                            // サポート
                            SettingsSectionHeader(title: "サポート")
                            
                            SettingsRow(icon: "exclamationmark.bubble.fill", title: "フィードバック") {
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
            }
            .sheet(isPresented: $showSafari) {
                if let url = urlToOpen {
                    SafariWebView(url: url)
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(isShowing: $showMailComposer)
            }
        }
    }
    
    // MARK: - Methods
    
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
        let nameParts = fullName.split(separator: " ")
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

    // T-nextへのURLを生成する関数
    private func createTnextURL() -> URL? {
        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "autoLoginAuthCd": "",
            "encryptedPassword": user?.encryptedPassword ?? "",
            "userId": user?.username ?? "",
            "parameterMap": ""
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        // カスタムエンコーディング
        let customEncoded = jsonString
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
        
        let encodedLoginInfo = customEncoded
            .replacingOccurrences(of: "%2522", with: "%22")
            .replacingOccurrences(of: "%255C", with: "%5C")
        
        let urlString = "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
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
    @State private var user: User?
    
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
        ユーザー名: \(user?.username ?? "不明")
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
} 
