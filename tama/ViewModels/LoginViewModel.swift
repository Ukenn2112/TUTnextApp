import Combine
import Foundation
import SwiftUI

/// ログインViewModel
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - 公開プロパティ

    @Published var account = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var loginErrorMessage: String?
    @Published var userName: String = ""
    @Published var showNFCTip = false

    // NFCリーダー
    let nfcReader = NFCReader()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初期化

    init() {
        // nfcReaderの変更をViewModelに伝播させる
        nfcReader.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - 計算プロパティ

    var combinedErrorMessage: String? {
        loginErrorMessage ?? nfcReader.errorMessage
    }

    var isLoginButtonDisabled: Bool {
        account.isEmpty || password.isEmpty || isLoading
    }

    // MARK: - パブリックメソッド

    /// NFC初回ヒント表示チェック
    func checkAndShowNFCTip() {
        if !UserDefaults.standard.bool(forKey: "hasShownNFCTip") {
            showNFCTip = true
            UserDefaults.standard.set(true, forKey: "hasShownNFCTip")
        }
    }

    /// エラーメッセージをクリア
    func clearErrors() {
        nfcReader.errorMessage = nil
        loginErrorMessage = nil
    }

    /// 学生証スキャンで取得した学生IDの処理
    func handleStudentIDChange(_ newValue: String) {
        if !newValue.isEmpty {
            account = newValue
        }
    }

    /// ログイン実行
    func performLogin(onSuccess: @escaping () -> Void) {
        isLoading = true
        clearErrors()

        // @MainActor上でタイムアウトを管理
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.isLoading {
                self.isLoading = false
                self.loginErrorMessage =
                    "ログインがタイムアウトしました。\nネットワーク接続を確認してください。\n\nもしネットワーク接続が良好であることが確認できた場合は、遅入りますが、admin@ukenn.top に取り合わせいてください。"
            }
        }

        AuthService.shared.login(account: account, password: password) { [weak self] result in
            timeoutTask.cancel()

            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let json):
                    self.handleLoginResponse(json, onSuccess: onSuccess)
                case .failure(let error):
                    self.handleLoginError(error)
                }
            }
        }
    }

    // MARK: - プライベートメソッド

    private func handleLoginResponse(_ json: [String: Any], onSuccess: @escaping () -> Void) {
        guard let statusDto = json["statusDto"] as? [String: Any],
            let success = statusDto["success"] as? Bool
        else {
            loginErrorMessage = AuthError.invalidResponse.localizedDescription
            return
        }

        if success {
            guard let userData = json["data"] as? [String: Any],
                userData["encryptedPassword"] != nil
            else {
                loginErrorMessage =
                    "サーバーからのレスポンスが不完全です。\n遅入りますが、admin@ukenn.top に取り合わせいてください。"
                return
            }
            saveUserData(userData, onSuccess: onSuccess)
        } else {
            if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                loginErrorMessage = messageList.first
            } else {
                loginErrorMessage = AuthError.loginFailed("ログインに失敗しました").localizedDescription
            }
        }
    }

    private func handleLoginError(_ error: Error) {
        if let authError = error as? AuthError {
            loginErrorMessage = authError.localizedDescription
        } else {
            loginErrorMessage = "エラー: \(error.localizedDescription)"
        }
    }

    private func saveUserData(_ userData: [String: Any], onSuccess: @escaping () -> Void) {
        if let user = UserService.shared.createUser(from: userData) {
            UserService.shared.saveUser(user) {
                DispatchQueue.main.async {
                    onSuccess()
                }
            }
        }
    }
}
