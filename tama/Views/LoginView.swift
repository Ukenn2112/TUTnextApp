import CoreNFC
import SwiftUI
import UserNotifications

struct LoginView: View {
    // MARK: - プロパティ
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var notificationService: NotificationService

    // 状態プロパティ
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var loginErrorMessage: String? = nil
    @State private var userName: String = ""
    @State private var showNFCTip = false

    // フォーカス管理
    @FocusState private var focusedField: Field?
    enum Field {
        case account
        case password
    }

    // NFCリーダー
    @StateObject private var nfcReader = NFCReader()

    // MARK: - 計算プロパティ
    private var errorColor: Color {
        colorScheme == .dark ? Color.red.opacity(0.8) : Color.red
    }

    private var combinedErrorMessage: String? {
        loginErrorMessage ?? nfcReader.errorMessage
    }

    private var isLoginButtonDisabled: Bool {
        account.isEmpty || password.isEmpty || isLoading
    }

    // MARK: - ボディ
    var body: some View {
        ZStack {
            // 背景色
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)

            // キーボードを閉じるための背景タップハンドラー
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }

            // メインコンテンツ
            VStack(spacing: 0) {
                Spacer()

                loginFormContent

                Spacer()
            }

            // フッター
            VStack {
                Spacer()
                Text("@Meikennと@Cursorが愛を込めて作った")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .alert("ログイン方法を選択", isPresented: $showNFCTip) {
            Button("手入力") {
                showNFCTip = false
                focusedField = .account
            }
            Button("学生証をスキャン", role: .cancel) {
                showNFCTip = false
                clearErrors()
                nfcReader.startSession()
            }
        } message: {
            Text("学生証をスキャンして自動入力するか、手動でアカウントを入力することができます。")
        }
        .onAppear(perform: checkAndShowNFCTip)
        .onChange(of: nfcReader.studentID) { oldValue, newValue in
            handleStudentIDChange(newValue)
        }
        .onChange(of: nfcReader.userName) { oldValue, newValue in
            withAnimation(.easeInOut) {
                userName = newValue
            }
        }
        .onChange(of: nfcReader.errorMessage) { oldValue, newValue in
            if newValue != nil {
                loginErrorMessage = nil
            }
        }
    }

    // MARK: - UIコンポーネント
    private var loginFormContent: some View {
        VStack(spacing: 0) {
            // NFCから取得したユーザー名
            if !userName.isEmpty {
                Text("\(userName) さん")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 5)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // タイトル
            Text("TUTnext へようこそ！👋")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

            // エラーメッセージ
            if let errorMessage = combinedErrorMessage {
                Text(errorMessage)
                    .foregroundColor(errorColor)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
            }

            // 入力フォーム
            inputFields

            // ログインボタン
            loginButton

            // 利用規約
            termsAndConditionsText
        }
    }

    // MARK: - 入力フォーム
    private var inputFields: some View {
        VStack(spacing: 15) {
            // NFCボタン付きアカウント入力フィールド
            ZStack(alignment: .trailing) {
                TextField("アカウント", text: $account)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                focusedField == .account ? Color.primary : Color.gray.opacity(0.3),
                                lineWidth: 1)
                    )
                    .textContentType(.username)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .focused($focusedField, equals: .account)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }

                // NFCスキャンボタン
                Button {
                    clearErrors()
                    nfcReader.startSession()
                } label: {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .padding(.trailing, 10)
            }

            // パスワード入力フィールド
            SecureField("パスワード", text: $password)
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            focusedField == .password ? Color.primary : Color.gray.opacity(0.3),
                            lineWidth: 1)
                )
                .textContentType(.password)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    if !isLoginButtonDisabled {
                        performLogin()
                    }
                }
        }
        .padding(.horizontal, 30)
    }

    // MARK: - ログインボタン
    private var loginButton: some View {
        Button(action: performLogin) {
            ZStack {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.white : Color.black)
                    .cornerRadius(25)
                    .frame(height: 50)
                    .shadow(
                        color: (colorScheme == .dark ? Color.white : Color.black)
                            .opacity(colorScheme == .dark ? 0.1 : 0.15),
                        radius: 5,
                        x: 0,
                        y: colorScheme == .dark ? -2 : 2
                    )

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(colorScheme == .dark ? .black : .white)
                } else {
                    Text("多摩大アカウントでサインイン")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .disabled(isLoginButtonDisabled)
    }

    // MARK: - 利用規約
    private var termsAndConditionsText: some View {
        HStack(spacing: 0) {
            Text("登録をすることで ")
                .foregroundColor(.secondary)
            Link("利用規約", destination: URL(string: "https://tama.qaq.tw/user-agreement")!)
                .foregroundColor(.blue)
            Text(" に同意したことになります")
                .foregroundColor(.secondary)
        }
        .font(.system(size: 12))
        .padding(.top, 20)
    }

    // MARK: - メソッド
    private func checkAndShowNFCTip() {
        if !UserDefaults.standard.bool(forKey: "hasShownNFCTip") {
            showNFCTip = true
            UserDefaults.standard.set(true, forKey: "hasShownNFCTip")
        }
    }

    private func clearErrors() {
        nfcReader.errorMessage = nil
        loginErrorMessage = nil
    }

    private func handleStudentIDChange(_ newValue: String) {
        if !newValue.isEmpty {
            account = newValue
            // 短い遅延の後にパスワードフィールドに自動フォーカス
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .password
            }
        }
    }

    private func performLogin() {
        isLoading = true
        clearErrors()

        // タイムアウト処理の設定
        let timeoutTask = createTimeoutTask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutTask)

        // ログインリクエストの実行
        AuthService.shared.login(account: account, password: password) { result in
            // レスポンスを受け取ったのでタイムアウトタスクをキャンセル
            timeoutTask.cancel()

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let json):
                    handleLoginResponse(json)
                case .failure(let error):
                    handleLoginError(error)
                }
            }
        }
    }

    private func createTimeoutTask() -> DispatchWorkItem {
        return DispatchWorkItem {
            if self.isLoading {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loginErrorMessage =
                        "ログインがタイムアウトしました。\nネットワーク接続を確認してください。\n\nもしネットワーク接続が良好であることが確認できた場合は、遅入りますが、admin@ukenn.top に取り合わせいてください。"
                    self.focusedField = .account
                }
            }
        }
    }

    private func handleLoginResponse(_ json: [String: Any]) {
        // JSON構造の検証
        guard let statusDto = json["statusDto"] as? [String: Any],
            let success = statusDto["success"] as? Bool
        else {
            loginErrorMessage = AuthError.invalidResponse.localizedDescription
            focusedField = .account
            return
        }

        if success {
            // ログイン成功
            guard let userData = json["data"] as? [String: Any],
                userData["encryptedPassword"] != nil
            else {
                loginErrorMessage = "サーバーからのレスポンスが不完全です。\n遅入りますが、admin@ukenn.top に取り合わせいてください。"
                focusedField = .account
                return
            }

            // ユーザーデータを保存してログイン完了
            saveUserData(userData)
        } else {
            // ログイン失敗
            if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                loginErrorMessage = messageList.first
            } else {
                loginErrorMessage = AuthError.loginFailed("ログインに失敗しました").localizedDescription
            }
            focusedField = .account
        }
    }

    private func handleLoginError(_ error: Error) {
        if let authError = error as? AuthError {
            loginErrorMessage = authError.localizedDescription
        } else {
            loginErrorMessage = "エラー: \(error.localizedDescription)"
        }
        focusedField = .account
    }

    private func saveUserData(_ userData: [String: Any]) {
        if let user = UserService.shared.createUser(from: userData) {
            UserService.shared.saveUser(user) {
                DispatchQueue.main.async {
                    // 通知許可をリクエスト
                    requestNotificationPermission()
                    // アニメーション付きでログイン状態を更新
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLoggedIn = true
                    }
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("ログイン成功後の通知権限状態: \(settings.authorizationStatus.rawValue)")
                switch settings.authorizationStatus {
                case .authorized:
                    // 既に許可されている場合、リモート通知を登録
                    self.notificationService.registerForRemoteNotifications()
                case .notDetermined:
                    // まだ決定されていない場合、許可をリクエスト
                    self.notificationService.requestAuthorization()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - プレビュー
#Preview {
    LoginView(isLoggedIn: .constant(false))
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
}
