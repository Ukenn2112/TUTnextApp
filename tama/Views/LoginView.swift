import SwiftUI

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isLoggedIn: Bool
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    // 定义允许的字符集
    private let allowedCharacters = CharacterSet.alphanumerics.union(.punctuationCharacters)
    
    // 添加错误信息颜色计算属性
    private var errorColor: Color {
        colorScheme == .dark ? 
            Color.red.opacity(0.8) : // 暗黑模式下使用较亮的红色
            Color.red
    }
    
    var body: some View {
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
                        .disableAutocorrection(true)  // 禁用自动纠正
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    SecureField("パスワード", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)  // 指定内容类型为密码
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 30)
                
                // ログインボタン
                Button(action: {
                    performLogin()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(colorScheme == .dark ? .black : .white)
                    } else {
                        Text("多摩大アカウントでサインイン")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(colorScheme == .dark ? Color.white : Color.black)
                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                .cornerRadius(25)
                .shadow(
                    color: (colorScheme == .dark ? Color.white : Color.black)
                        .opacity(colorScheme == .dark ? 0.1 : 0.15),
                    radius: 5,
                    x: 0,
                    y: colorScheme == .dark ? -2 : 2
                )
                .padding(.horizontal, 30)
                .padding(.top, 15)
                .disabled(account.isEmpty || password.isEmpty || isLoading)
                
                // 利用規約
                HStack(spacing: 0) {
                    Text("登録をすることで ")
                        .foregroundColor(.secondary)
                    Text("利用規約")
                        .foregroundColor(.blue)
                    Text(" に同意したことになります")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 12))
                .padding(.top, 20)
            }
            
            Spacer()  // 底部弹性空间
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.login(account: account, password: password) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let json):
                    if let statusDto = json["statusDto"] as? [String: Any] {
                        if let success = statusDto["success"] as? Bool, success {
                            // ログイン成功
                            if let userData = json["data"] as? [String: Any] {
                                // ユーザー情報の保存処理
                                self.saveUserData(userData)
                                
                                // ログイン状態を更新
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    self.isLoggedIn = true
                                }
                            } else {
                                self.errorMessage = AuthError.userDataNotFound.localizedDescription
                            }
                        } else {
                            // ログイン失敗
                            if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                                self.errorMessage = messageList.first
                            } else {
                                self.errorMessage = AuthError.loginFailed("ログインに失敗しました").localizedDescription
                            }
                        }
                    } else {
                        self.errorMessage = AuthError.invalidResponse.localizedDescription
                    }
                    
                case .failure(let error):
                    if let authError = error as? AuthError {
                        self.errorMessage = authError.localizedDescription
                    } else {
                        self.errorMessage = "エラー: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func saveUserData(_ userData: [String: Any]) {
        if let user = UserService.shared.createUser(from: userData) {
            UserService.shared.saveUser(user)
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
        .preferredColorScheme(.light)
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
        .preferredColorScheme(.dark)
}
