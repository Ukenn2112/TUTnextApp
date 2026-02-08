//
//  LoginView.swift
//  TUTnext
//
//  Glassmorphism Auth View
//

import SwiftUI
import CoreNFC

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var ratingService: RatingService
    
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var loginErrorMessage: String? = nil
    @State private var userName: String = ""
    @State private var showNFCTip = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case account
        case password
    }
    
    @StateObject private var nfcReader = NFCReader()
    
    private var isLoginButtonDisabled: Bool {
        account.isEmpty || password.isEmpty || isLoading
    }
    
    var body: some View {
        ZStack {
            // Glassmorphism Background
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Welcome Content
                loginFormContent
                
                Spacer()
                
                // Footer
                footerView
            }
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
        .onChange(of: nfcReader.studentID) { _, newValue in
            handleStudentIDChange(newValue)
        }
        .onChange(of: nfcReader.userName) { _, newValue in
            withAnimation(.easeInOut) {
                userName = newValue
            }
        }
        .onChange(of: nfcReader.errorMessage) { _, newValue in
            if newValue != nil {
                loginErrorMessage = nil
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Login Form Content
    private var loginFormContent: some View {
        VStack(spacing: 0) {
            // NFCから取得したユーザー名
            if !userName.isEmpty {
                StyledText("\(userName) さん", style: .headlineMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Title
            StyledText("TUTnext へようこそ！👋", style: .headlineMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.bottom, 32)
            
            // Error Message
            if let errorMessage = loginErrorMessage ?? nfcReader.errorMessage {
                GlassCard(variant: .outline) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .typography(.bodyMedium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
            }
            
            // Input Fields
            inputFields
            
            // Login Button
            loginButton
            
            // Terms
            termsAndConditionsText
        }
    }
    
    // MARK: - Input Fields
    private var inputFields: some View {
        VStack(spacing: 16) {
            // Account Field with NFC
            GlassCard(variant: .outline) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    TextField("アカウント", text: $account)
                        .textContentType(.username)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.none)
                        .typography(.bodyMedium)
                        .focused($focusedField, equals: .account)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                    
                    // NFC Scan Button
                    Button {
                        clearErrors()
                        nfcReader.startSession()
                    } label: {
                        Image(systemName: "nfc")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .account ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            // Password Field
            GlassCard(variant: .outline) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
                        .typography(.bodyMedium)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit {
                            if !isLoginButtonDisabled {
                                performLogin()
                            }
                        }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .password ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Login Button
    private var loginButton: some View {
        GlassLoadingButton("多摩大アカウントでサインイン", isLoading: $isLoading) {
            performLogin()
        }
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .disabled(isLoginButtonDisabled)
    }
    
    // MARK: - Terms
    private var termsAndConditionsText: some View {
        HStack(spacing: 4) {
            Text("登録をすると")
                .foregroundColor(.secondary)
                .typography(.caption)
            Link("利用規約", destination: URL(string: "https://tama.qaq.tw/user-agreement")!)
                .foregroundColor(.accentColor)
                .typography(.caption)
            Text("に同意したことになります")
                .foregroundColor(.secondary)
                .typography(.caption)
        }
        .padding(.top, 24)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        StyledText("@Meikennと@Cursorが愛を込めて作った", style: .caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 16)
    }
    
    // MARK: - Methods
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .password
            }
        }
    }
    
    private func performLogin() {
        isLoading = true
        clearErrors()
        
        let timeoutTask = createTimeoutTask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeoutTask)
        
        AuthService.shared.login(account: account, password: password) { result in
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
                    self.loginErrorMessage = "ログインがタイムアウトしました。\nネットワーク接続を確認してください。"
                    self.focusedField = .account
                }
            }
        }
    }
    
    private func handleLoginResponse(_ json: [String: Any]) {
        guard let statusDto = json["statusDto"] as? [String: Any],
              let success = statusDto["success"] as? Bool
        else {
            loginErrorMessage = AuthError.invalidResponse.localizedDescription
            focusedField = .account
            return
        }
        
        if success {
            guard let userData = json["data"] as? [String: Any],
                  userData["encryptedPassword"] != nil
            else {
                loginErrorMessage = "サーバーからのレスポンスが不完全です。"
                focusedField = .account
                return
            }
            saveUserData(userData)
        } else {
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
                    requestNotificationPermission()
                    ratingService.recordSignificantEvent()
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
                switch settings.authorizationStatus {
                case .authorized:
                    self.notificationService.registerForRemoteNotifications()
                case .notDetermined:
                    self.notificationService.requestAuthorization()
                default:
                    break
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
        .environmentObject(ThemeManager.shared)
        .environmentObject(NotificationService.shared)
}
