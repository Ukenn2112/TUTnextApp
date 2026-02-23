import CoreNFC
import SwiftUI
import UserNotifications

struct LoginView: View {
    // MARK: - プロパティ
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var ratingService: RatingService

    @StateObject private var viewModel = LoginViewModel()

    // フォーカス管理
    @FocusState private var focusedField: Field?
    enum Field {
        case account
        case password
    }

    // NFCボタンのシマーアニメーション
    @State private var nfcShimmer = false

    // MARK: - 計算プロパティ
    private var errorColor: Color { .red }

    // MARK: - ボディ
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            loginFormContent

            Spacer()

            // フッター
            Text("@Meikennと@Claudeが愛を込めて作った")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(UIColor.systemBackground)
                .onTapGesture { focusedField = nil }
        )
        .alert("ログイン方法を選択", isPresented: $viewModel.showNFCTip) {
            Button("手入力") {
                viewModel.showNFCTip = false
                focusedField = .account
            }
            Button("学生証をスキャン", role: .cancel) {
                viewModel.showNFCTip = false
                viewModel.clearErrors()
                viewModel.nfcReader.startSession()
            }
        } message: {
            Text("学生証をスキャンして自動入力するか、手動でアカウントを入力することができます。")
        }
        .onAppear(perform: viewModel.checkAndShowNFCTip)
        .onChange(of: viewModel.nfcReader.studentID) { _, newValue in
            viewModel.handleStudentIDChange(newValue)
            if !newValue.isEmpty {
                // NFCセッションのUI消去アニメーション完了を待つ
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    focusedField = .password
                }
            }
        }
        .onChange(of: viewModel.nfcReader.userName) { _, newValue in
            withAnimation(.easeInOut) {
                viewModel.userName = newValue
            }
        }
        .onChange(of: viewModel.nfcReader.errorMessage) { _, newValue in
            if newValue != nil {
                viewModel.loginErrorMessage = nil
            }
        }
        .onChange(of: viewModel.loginErrorMessage) { _, newValue in
            if newValue != nil {
                focusedField = .account
            }
        }
    }

    // MARK: - UIコンポーネント
    private var loginFormContent: some View {
        VStack(spacing: 0) {
            // NFCから取得したユーザー名
            if !viewModel.userName.isEmpty {
                Text("\(viewModel.userName) さん")
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
            if let errorMessage = viewModel.combinedErrorMessage {
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
                TextField("アカウント", text: $viewModel.account)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                focusedField == .account ? Color.primary : Color.gray.opacity(0.3),
                                lineWidth: 1)
                            .animation(.easeOut(duration: 0.2), value: focusedField)
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

                // NFCスキャンボタン（シマーで注目を引く）
                Button {
                    viewModel.clearErrors()
                    viewModel.nfcReader.startSession()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 13))
                        Text("学生証スキャン")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.secondarySystemFill))
                    )
                    .overlay(
                        GeometryReader { geo in
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.15), location: 0.4),
                                    .init(color: .white.opacity(0.55), location: 0.5),
                                    .init(color: .white.opacity(0.15), location: 0.6),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 2)
                            .offset(x: nfcShimmer ? geo.size.width : -geo.size.width * 2)
                            .animation(
                                .linear(duration: 1.8)
                                    .repeatForever(autoreverses: false),
                                value: nfcShimmer
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .padding(.trailing, 6)
                .onAppear { nfcShimmer = true }
            }

            // パスワード入力フィールド
            SecureField("パスワード", text: $viewModel.password)
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            focusedField == .password ? Color.primary : Color.gray.opacity(0.3),
                            lineWidth: 1)
                        .animation(.easeOut(duration: 0.2), value: focusedField)
                )
                .textContentType(.password)
                .font(.system(size: 18))
                .foregroundColor(.primary)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    if !viewModel.isLoginButtonDisabled {
                        performLogin()
                    }
                }
        }
        .padding(.horizontal, 30)
    }

    // MARK: - ログインボタン
    private var loginButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: performLogin) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("多摩大アカウントでサインイン")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Color(UIColor.systemBackground))
                        }
                    }
                }
                .controlSize(.extraLarge)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .disabled(viewModel.isLoginButtonDisabled)
                .tint(Color(UIColor.label))
            } else {
                Button(action: performLogin) {
                    ZStack {
                        Rectangle()
                            .fill(Color(UIColor.label))
                            .cornerRadius(25)
                            .frame(height: 50)
                            .shadow(
                                color: Color(UIColor.label).opacity(0.12),
                                radius: 5,
                                x: 0,
                                y: 2
                            )

                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(Color(UIColor.systemBackground))
                        } else {
                            Text("多摩大アカウントでサインイン")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(UIColor.systemBackground))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .disabled(viewModel.isLoginButtonDisabled)
            }
        }
    }

    @available(iOS 26.0, *)
    private struct NoScaleGlassButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(1.0)
                .animation(nil, value: configuration.isPressed)
        }
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

    private func performLogin() {
        viewModel.performLogin {
            // 通知許可をリクエスト
            requestNotificationPermission()
            // ログイン成功の重要イベントを記録
            ratingService.recordSignificantEvent()
            // アニメーション付きでログイン状態を更新
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoggedIn = true
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("ログイン成功後の通知権限状態: \(settings.authorizationStatus.rawValue)")
                switch settings.authorizationStatus {
                case .authorized:
                    notificationService.registerForRemoteNotifications()
                case .notDetermined:
                    notificationService.requestAuthorization()
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
        .environmentObject(RatingService.shared)
}
