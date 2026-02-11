import MessageUI
import SafariServices
import SwiftUI

/// ユーザー設定画面
struct UserSettingsView: View {

    // MARK: - プロパティ

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var ratingService: RatingService

    @StateObject private var viewModel = UserSettingsViewModel()

    // MARK: - ボディ

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        userInfoSection
                            .padding(.bottom, 12)

                        settingsSection

                        appInfoSection
                            .padding(.top, 40)
                            .padding(.bottom, 50)

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarTitle("設定", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
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
                DarkModeSettingsView(appearanceManager: appearanceManager)
            }
            .preferredColorScheme(appearanceManager.colorSchemeOverride)
        }
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    // MARK: - サブビュー

    /// ユーザー情報セクション
    private var userInfoSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(viewModel.getInitials())
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(colorScheme == .dark ? 0.8 : 1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.user?.fullName ?? "ユーザー名")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("@\(viewModel.user?.username ?? "username")")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
        }
    }

    /// 設定セクション
    private var settingsSection: some View {
        VStack(spacing: 0) {
            // アカウント設定
            SettingsSectionHeader(title: NSLocalizedString("アカウント設定", comment: ""))
            SettingsRow(
                icon: "lock.fill",
                title: NSLocalizedString("パスワード変更", comment: "")
            ) {
                viewModel.openPasswordChangeURL()
            }

            // アプリ設定
            SettingsSectionHeader(title: NSLocalizedString("アプリ設定", comment: ""))
            SettingsRow(
                icon: "calendar.badge.plus",
                title: NSLocalizedString("時間割をカレンダーへ", comment: "")
            ) {
                viewModel.openURL("https://tama.qaq.tw/")
            }

            notificationSettingsRow
            languageSettingsRow
            darkModeSettingsRow

            // その他
            SettingsSectionHeader(title: NSLocalizedString("その他", comment: ""))
            SettingsRow(
                icon: "doc.text.fill",
                title: NSLocalizedString("利用規約", comment: "")
            ) {
                viewModel.openURL("https://tama.qaq.tw/user-agreement")
            }
            SettingsRow(
                icon: "hand.raised.fill",
                title: NSLocalizedString("プライバシーポリシー", comment: "")
            ) {
                viewModel.openURL("https://tama.qaq.tw/policy")
            }
            SettingsRow(
                icon: "exclamationmark.bubble.fill",
                title: NSLocalizedString("フィードバック", comment: "")
            ) {
                viewModel.sendFeedback()
            }
            SettingsRow(
                icon: "star.fill",
                title: NSLocalizedString("アプリを評価", comment: "")
            ) {
                ratingService.requestRatingManually()
            }

            logoutButton
        }
    }

    /// 通知設定行
    private var notificationSettingsRow: some View {
        Button(action: { handleNotificationSettings() }) {
            SettingsDetailRow(
                icon: notificationService.isAuthorized ? "bell.fill" : "bell.slash",
                title: "通知設定",
                detail: notificationStatusText
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 言語設定行
    private var languageSettingsRow: some View {
        Button(action: { languageService.openLanguageSettings() }) {
            SettingsDetailRow(
                icon: "globe",
                title: "言語",
                detail: languageService.currentLanguage
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// ダークモード設定行
    private var darkModeSettingsRow: some View {
        Button(action: { viewModel.showingDarkModeSheet = true }) {
            SettingsDetailRow(
                icon: "moon.fill",
                title: "ダークモード",
                detail: darkModeText
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// ログアウトボタン
    private var logoutButton: some View {
        Button(action: { performLogout() }) {
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

    /// アプリ情報セクション
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Text("TUTnext")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Text(
                "バージョン \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
            )
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
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

// MARK: - 詳細付き設定行

/// アイコン、タイトル、詳細テキスト、シェブロンを含む設定行
private struct SettingsDetailRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            Text(title)
                .foregroundColor(.primary)
                .font(.system(size: 16))
            Spacer()
            Text(detail)
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - ダークモード設定画面

/// 外観モード（ライト/ダーク/システム）を選択するシート
struct DarkModeSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appearanceManager: AppearanceManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // ヘッダーアイコン
                    HStack(spacing: 20) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .light ? .orange : .gray)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .dark ? .blue : .gray)
                    }
                    .padding(.top, 20)

                    // オプションカード
                    VStack(spacing: 16) {
                        appearanceOptionCard(
                            title: NSLocalizedString("システムに従う", comment: ""),
                            icon: "gear",
                            description: NSLocalizedString("デバイスの設定に合わせて自動的に切り替えます", comment: ""),
                            isSelected: appearanceManager.mode == .system
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.system)
                            }
                        }

                        appearanceOptionCard(
                            title: NSLocalizedString("ライトモード", comment: ""),
                            icon: "sun.max.fill",
                            description: NSLocalizedString("明るい外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.mode == .light
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.light)
                            }
                        }

                        appearanceOptionCard(
                            title: NSLocalizedString("ダークモード", comment: ""),
                            icon: "moon.stars.fill",
                            description: NSLocalizedString("暗い外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.mode == .dark
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.dark)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("外観モード")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("完了")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .preferredColorScheme(appearanceManager.colorSchemeOverride)
        }
    }

    // MARK: - カードコンポーネント

    private func appearanceOptionCard(
        title: String,
        icon: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? Color.blue.opacity(0.2)
                                : Color(UIColor.secondarySystemBackground)
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - サポートビュー

/// 設定セクションのヘッダー
struct SettingsSectionHeader: View {
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

/// 設定行（アイコン、タイトル、シェブロン）
struct SettingsRow: View {
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

/// メール作成ビュー
struct MailComposerView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject("TUTnext アプリフィードバック")
        composer.setToRecipients(["admin@ukenn.top"])

        let appVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"
        let emailBody = """

            ------------------------------
            【システム情報】
            アプリバージョン: \(appVersion) (\(buildNumber))
            デバイス: \(UIDevice.current.model)
            OS: iOS \(UIDevice.current.systemVersion)
            ------------------------------
            """
        composer.setMessageBody(emailBody, isHTML: false)
        return composer
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.isShowing = false
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
