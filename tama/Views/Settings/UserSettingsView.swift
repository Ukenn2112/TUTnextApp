import MessageUI
import SafariServices
import SwiftUI

/// ユーザー設定画面
struct UserSettingsView: View {

    // MARK: - プロパティ

    @Environment(\.dismiss) private var dismiss
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var ratingService: RatingService

    @StateObject private var viewModel = UserSettingsViewModel()

    // MARK: - ボディ

    var body: some View {
        NavigationStack {
            Form {
                userInfoSection
                accountSettingsSection
                appSettingsSection
                otherSection
                logoutSection
            }
            .navigationBarTitle("設定", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }
                }
            }
            .onAppear {
                viewModel.loadUserData()
                notificationService.checkAuthorizationStatus()
            }
            .sheet(isPresented: $viewModel.showSafari) {
                if let url = viewModel.urlToOpen {
                    SafariWebView(url: url)
                }
            }
            .sheet(isPresented: $viewModel.showMailComposer) {
                MailComposerView(isShowing: $viewModel.showMailComposer)
            }
            .sheet(isPresented: $viewModel.showingDarkModeSheet) {
                DarkModeSettingsView()
                    .environmentObject(appearanceManager)
            }
        }
    }

    // MARK: - セクション

    /// ユーザー情報セクション
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 14) {
                Text(viewModel.getInitials())
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.user?.fullName ?? "ユーザー名")
                        .font(.title3.weight(.semibold))
                    Text("@\(viewModel.user?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// アカウント設定セクション
    private var accountSettingsSection: some View {
        Section(NSLocalizedString("アカウント設定", comment: "")) {
            settingsButton(
                NSLocalizedString("パスワード変更", comment: ""),
                icon: "lock.fill",
                color: .blue
            ) {
                viewModel.openPasswordChangeURL()
            }
        }
    }

    /// アプリ設定セクション
    private var appSettingsSection: some View {
        Section(NSLocalizedString("アプリ設定", comment: "")) {
            settingsButton(
                NSLocalizedString("時間割をカレンダーへ", comment: ""),
                icon: "calendar.badge.plus",
                color: .orange
            ) {
                viewModel.openURL("https://tama.qaq.tw/")
            }

            settingsButton(
                NSLocalizedString("通知設定", comment: ""),
                icon: notificationService.isAuthorized ? "bell.fill" : "bell.slash",
                color: .red,
                detail: notificationStatusText
            ) {
                handleNotificationSettings()
            }

            settingsButton(
                NSLocalizedString("言語", comment: ""),
                icon: "globe",
                color: .teal,
                detail: languageService.currentLanguage
            ) {
                languageService.openLanguageSettings()
            }

            settingsButton(
                NSLocalizedString("ダークモード", comment: ""),
                icon: "moon.fill",
                color: .indigo,
                detail: darkModeText
            ) {
                viewModel.showingDarkModeSheet = true
            }
        }
    }

    /// その他セクション
    private var otherSection: some View {
        Section(NSLocalizedString("その他", comment: "")) {
            settingsButton(
                NSLocalizedString("利用規約", comment: ""),
                icon: "doc.text.fill",
                color: .gray
            ) {
                viewModel.openURL("https://tama.qaq.tw/user-agreement")
            }

            settingsButton(
                NSLocalizedString("プライバシーポリシー", comment: ""),
                icon: "hand.raised.fill",
                color: .blue
            ) {
                viewModel.openURL("https://tama.qaq.tw/policy")
            }

            settingsButton(
                NSLocalizedString("フィードバック", comment: ""),
                icon: "envelope.fill",
                color: .mint
            ) {
                viewModel.sendFeedback()
            }

            settingsButton(
                NSLocalizedString("アプリを評価", comment: ""),
                icon: "star.fill",
                color: .yellow
            ) {
                ratingService.requestRatingManually()
            }
        }
    }

    /// ログアウトセクション
    private var logoutSection: some View {
        Section {
            Button(action: { performLogout() }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(NSLocalizedString("ログアウト", comment: ""))
                        .foregroundStyle(.red)
                }
            }
            .tint(.red)
        } footer: {
            VStack(spacing: 4) {
                Text("TUTnext")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(
                    "バージョン \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
    }

    // MARK: - コンポーネント

    /// iOS設定アプリスタイルのアイコンバッジ付き設定行
    private func settingsButton(
        _ title: String,
        icon: String,
        color: Color,
        detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .foregroundStyle(.primary)

                if let detail {
                    Spacer()
                    Text(detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }

    // MARK: - 計算プロパティ

    /// 通知状態のテキスト
    private var notificationStatusText: String {
        if notificationService.isAuthorized {
            return notificationService.isRegistered
                ? NSLocalizedString("オン", comment: "")
                : NSLocalizedString("設定中...", comment: "")
        }
        return NSLocalizedString("オフ", comment: "")
    }

    /// ダークモードのテキスト
    private var darkModeText: String {
        switch appearanceManager.mode {
        case .system:
            return NSLocalizedString("システムに従う", comment: "")
        case .light:
            return NSLocalizedString("ライト", comment: "")
        case .dark:
            return NSLocalizedString("ダーク", comment: "")
        }
    }

    // MARK: - プライベートメソッド

    private func handleNotificationSettings() {
        if notificationService.isAuthorized && !notificationService.isRegistered {
            notificationService.registerForRemoteNotifications()
        } else {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url) { success in
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.notificationService.checkAuthorizationStatus()
                        }
                    }
                }
            }
        }
    }

    private func performLogout() {
        viewModel.logout {
            UserService.shared.clearCurrentUser()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLoggedIn = false
                }
            }
        }
    }
}

// MARK: - プレビュー

#Preview {
    UserSettingsView(isLoggedIn: .constant(true))
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(LanguageService.shared)
        .environmentObject(RatingService.shared)
}
