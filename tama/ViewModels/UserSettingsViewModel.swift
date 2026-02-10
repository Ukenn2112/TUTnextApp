import Foundation
import MessageUI
import SwiftUI

/// ユーザー設定ViewModel
@MainActor
final class UserSettingsViewModel: ObservableObject {

    // MARK: - 公開プロパティ

    @Published var user: User? = nil
    @Published var showSafari = false
    @Published var urlToOpen: URL? = nil
    @Published var showMailComposer = false
    @Published var showingDarkModeSheet = false

    // MARK: - パブリックメソッド

    /// ユーザーデータを読み込み
    func loadUserData() {
        user = UserService.shared.getCurrentUser()
    }

    /// ユーザー名のイニシャルを取得
    func getInitials() -> String {
        guard let fullName = user?.fullName else { return "?" }
        let nameParts = fullName.split(separator: "　")
        if let firstPart = nameParts.first {
            return String(firstPart.prefix(2))
        }
        return "?"
    }

    /// パスワード変更ページを開く
    func openPasswordChangeURL() {
        urlToOpen = URL(string: "https://google.tama.ac.jp/unicornidm/user/tama/password/")
        showSafari = true
    }

    /// Safari で URL を開く
    func openURL(_ urlString: String) {
        urlToOpen = URL(string: urlString)
        showSafari = true
    }

    /// フィードバックを送信
    func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            let emailAddress = "admin@ukenn.top"
            let subject = "TUTnext アプリフィードバック"
            if let url = URL(
                string:
                    "mailto:\(emailAddress)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            ) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// ログアウト処理
    func logout(onComplete: @escaping () -> Void) {
        guard let user = user, let encryptedPassword = user.encryptedPassword else {
            onComplete()
            return
        }

        AuthService.shared.logout(userId: user.username, encryptedPassword: encryptedPassword) {
            _ in
            DispatchQueue.main.async {
                onComplete()
            }
        }
    }
}
