import SwiftUI
import UserNotifications

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isLoggedIn: Bool
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject private var notificationService: NotificationService
    
    // フォーカス管理のための状態
    @FocusState private var focusedField: Field?
    
    // フォーカスフィールドの定義
    enum Field {
        case account
        case password
    }
    
    // 定义允许的字符集
    private let allowedCharacters = CharacterSet.alphanumerics.union(.punctuationCharacters)
    
    // 添加错误信息颜色计算属性
    private var errorColor: Color {
        colorScheme == .dark ? 
            Color.red.opacity(0.8) : // 暗黑模式下使用较亮的红色
            Color.red
    }
    
    var body: some View {
        ZStack {
            // 背景色
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            // 背景タップ用の透明なレイヤー
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            
            VStack(spacing: 0) {
                Spacer()  // 顶部弹性空间
                
                // 主要内容区域
                VStack(spacing: 0) {
                    // タイトル
                    Text("TUTnext へようこそ！👋")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)  // 标题和表单之间的间距
                    
                    // エラーメッセージ（存在する場合）
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(errorColor)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 10)
                    }
                    
                    // 入力フォーム
                    VStack(spacing: 15) {
                        TextField("アカウント", text: $account)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.username)  // 指定内容类型为用户名
                            .keyboardType(.asciiCapable)  // 限制键盘为ASCII字符
                            .autocapitalization(.none)  // 禁用自动大写
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .focused($focusedField, equals: .account)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .password
                            }
                        
                        SecureField("パスワード", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)  // 指定内容类型为密码
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                if !account.isEmpty && !password.isEmpty && !isLoading {
                                    performLogin()
                                }
                            }
                    }
                    .padding(.horizontal, 30)
                    
                    // ログインボタン
                    Button(action: {
                        performLogin()
                    }) {
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
                                    .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .disabled(account.isEmpty || password.isEmpty || isLoading)
                    
                    // 利用規約
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
                
                Spacer()  // 底部弹性空间
            }
        }
    }
    
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        // タイムアウト処理を追加
        let timeoutTask = DispatchWorkItem {
            if isLoading {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "ログインがタイムアウトしました。\nネットワーク接続を確認してください。\n\nもしネットワーク接続が良好であることが確認できた場合は、遅入りますが、admin@ukenn.top に取り合わせいてください。"
                    focusedField = .account
                }
            }
        }
        
        // 5秒後にタイムアウト処理を実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutTask)
        
        AuthService.shared.login(account: account, password: password) { result in
            // タイムアウト処理をキャンセル
            timeoutTask.cancel()
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let json):
                    // JSONデータの検証を強化
                    guard let statusDto = json["statusDto"] as? [String: Any] else {
                        self.errorMessage = AuthError.invalidResponse.localizedDescription
                        self.focusedField = .account
                        return
                    }
                    
                    guard let success = statusDto["success"] as? Bool else {
                        self.errorMessage = AuthError.invalidResponse.localizedDescription
                        self.focusedField = .account
                        return
                    }
                    
                    if success {
                        // ログイン成功
                        guard let userData = json["data"] as? [String: Any] else {
                            self.errorMessage = AuthError.userDataNotFound.localizedDescription
                            self.focusedField = .account
                            return
                        }
                        
                        // ユーザーデータの検証 - encryptedPasswordの存在チェック
                        guard userData["encryptedPassword"] != nil else {
                            self.errorMessage = "サーバーからのレスポンスが不完全です。\n遅入りますが、admin@ukenn.top に取り合わせいてください。"
                            self.focusedField = .account
                            return
                        }
                        
                        // ユーザー情報の保存処理
                        self.saveUserData(userData)
                    } else {
                        // ログイン失敗
                        if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                            self.errorMessage = messageList.first
                        } else {
                            self.errorMessage = AuthError.loginFailed("ログインに失敗しました").localizedDescription
                        }
                        self.focusedField = .account // エラー時にアカウント入力欄にフォーカス
                    }
                    
                case .failure(let error):
                    if let authError = error as? AuthError {
                        self.errorMessage = authError.localizedDescription
                    } else {
                        self.errorMessage = "エラー: \(error.localizedDescription)"
                    }
                    self.focusedField = .account // エラー時にアカウント入力欄にフォーカス
                }
            }
        }
    }
    
    private func saveUserData(_ userData: [String: Any]) {
        // encryptedPasswordの存在を再確認（冗長チェック - すでにperformLoginで検証済み）
        guard userData["encryptedPassword"] != nil else {
            print("致命的エラー: saveUserData - encryptedPasswordが見つかりません")
            // performLoginでチェック済みなので、このケースに入ることは通常ありません
            return
        }
        
        if let user = UserService.shared.createUser(from: userData) {
            UserService.shared.saveUser(user) {
                // ユーザーデータの保存が完了した後に通知権限をリクエストし、ログイン状態を更新
                DispatchQueue.main.async {
                    // 通知権限をリクエスト
                    self.requestNotificationPermission()
                    
                    // ログイン状態を更新
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isLoggedIn = true
                    }
                }
            }
        }
    }
    
    // 通知権限をリクエスト
    private func requestNotificationPermission() {
        // 通知権限の状態を確認
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("ログイン成功後の通知権限状態: \(settings.authorizationStatus.rawValue)")
                
                // 権限がある場合でデバイストークンがない場合は登録
                if settings.authorizationStatus == .authorized {
                    self.notificationService.registerForRemoteNotifications()
                }
                // まだ決定されていない場合のみリクエスト
                else if settings.authorizationStatus == .notDetermined {
                    self.notificationService.requestAuthorization()
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
}
