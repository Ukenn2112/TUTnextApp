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

    /// 画面に出しているエラーメッセージ。
    /// ViewModel の値をそのまま使うと出入りを `withMotion` で動かせないため、変化のたびにここへ写す
    @State private var displayedErrorMessage: String?

    /// ログインに失敗した回数。入力欄を揺らし、エラーの触覚を返すきっかけにする
    @State private var loginFailureCount = 0

    // MARK: - 計算プロパティ
    private var errorColor: Color { .red }

    // MARK: - ボディ
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            loginFormContent
                .readableWidth(ReadableWidth.form)

            Spacer()

            // フッター
            Text("@Meikennと@Claudeが愛を込めて作った")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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
        .onAppear {
            displayedErrorMessage = viewModel.combinedErrorMessage
            viewModel.checkAndShowNFCTip()
        }
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
            withMotion(Motion.standard) {
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
                loginFailureCount += 1
            }
        }
        .onChange(of: viewModel.combinedErrorMessage) { _, newValue in
            withMotion(Motion.quick) {
                displayedErrorMessage = newValue
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
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 5)
                    .motionTransition(.fade)
            }

            // タイトル
            Text("TUTnext へようこそ！")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

            // エラーメッセージ
            if let errorMessage = displayedErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(errorColor)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    .motionTransition(.fade)
            }

            // 入力フォーム（ログインに失敗するたびに揺らしてエラーの触覚を返す）
            inputFields
                .shake(trigger: loginFailureCount)
                .errorHaptic(trigger: loginFailureCount)

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
                            .motionAnimation(Motion.quick, value: focusedField)
                    )
                    .textContentType(.username)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
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
                    // `.secondary`（層の様式）だとボタンの前景色＝アプリの主色を継いで薄い主色になるため、
                    // 固定の灰色 `Color.secondary` にする
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.secondarySystemFill))
                    )
                    .overlay { NFCButtonShimmer() }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .padding(.trailing, 6)
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
                        .motionAnimation(Motion.quick, value: focusedField)
                )
                .textContentType(.password)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
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

    /// サインインボタン。
    ///
    /// 読み込み中も文字は消さずに透明にして残し、その上にインジケーターを重ねるので、
    /// 状態が変わってもボタンの大きさ・形は変わらない。
    /// 背景はアプリの文字色（`label`）で塗るため、文字とインジケーターは反転色（`systemBackground`）で描く
    /// （Prominentスタイルの既定の白文字だと、ダークモードで白地に白文字になるため）
    private var loginButton: some View {
        Button(action: performLogin) {
            Text("多摩大アカウントでサインイン")
                .foregroundStyle(Color(UIColor.systemBackground))
                .frame(maxWidth: .infinity)
                .opacity(viewModel.isLoading ? 0 : 1)
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Color(UIColor.systemBackground))
                            .motionTransition(.fade)
                    }
                }
                .motionAnimation(Motion.quick, value: viewModel.isLoading)
        }
        .prominentLoginButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.extraLarge)
        .tint(Color(UIColor.label))
        .disabled(viewModel.isLoginButtonDisabled)
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }

    // MARK: - 利用規約
    /// 利用規約のURL（固定の文字列だが、強制アンラップで落ちないよう Optional のまま扱う）
    private static let termsURL = URL(string: "https://tama.qaq.tw/user-agreement")

    private var termsAndConditionsText: some View {
        HStack(spacing: 0) {
            Text("登録をすることで ")
                .foregroundStyle(.secondary)
            if let termsURL = Self.termsURL {
                Link("利用規約", destination: termsURL)
                    .foregroundStyle(.blue)
            } else {
                Text("利用規約")
                    .foregroundStyle(.secondary)
            }
            Text(" に同意したことになります")
                .foregroundStyle(.secondary)
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
            // 落ち着いたクロスフェードでログイン状態を更新
            withMotion(Motion.standard) {
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

// MARK: - 学生証スキャンボタンのきらめき

/// 学生証スキャンボタンの上を左から右へ流れるきらめき（注目を引くため）。
/// 「視差効果を減らす」が有効なとき、またはアプリが前面にないときは何も描かない（静止）。
/// 流れる帯ごと外すので、繰り返しのアニメーションも残らない
private struct NFCButtonShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if !reduceMotion && scenePhase == .active {
            Sweep()
        }
    }

    private struct Sweep: View {
        @State private var isSweeping = false

        var body: some View {
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
                .offset(x: isSweeping ? geo.size.width : -geo.size.width * 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(Motion.shimmer) {
                    isSweeping = true
                }
            }
        }
    }
}

// MARK: - ボタンスタイル

private extension View {

    /// 強調ボタンのスタイル（iOS 26以降はLiquid Glass、それ以前は標準の塗りつぶし）
    @ViewBuilder func prominentLoginButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
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
