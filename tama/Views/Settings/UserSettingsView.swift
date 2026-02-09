//
//  UserSettingsView.swift
//  TUTnext
//
//  Glassmorphism User Settings View
//

import SwiftUI
import SafariServices
import MessageUI

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoggedIn: Bool
    @State private var user: LegacyUser?
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var ratingService: RatingService
    @Environment(\.authService) private var authService
    @Environment(\.userService) private var userService
    
    @State private var showSafari: Bool = false
    @State private var urlToOpen: URL? = nil
    @State private var showMailComposer: Bool = false
    @State private var showingDarkModeSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // User Profile Section
                userProfileSection
                    .padding(.bottom, 12)
                
                // Settings Sections
                VStack(spacing: 0) {
                    // Account Settings
                    sectionHeader("アカウント設定")
                    
                    settingsRow(
                        icon: "lock.fill",
                        title: "パスワード変更"
                    ) {
                        openPasswordChangeURL()
                    }
                    
                    // App Settings
                    sectionHeader("アプリ設定")
                    
                    settingsRow(
                        icon: "calendar.badge.plus",
                        title: "時間割をカレンダーへ"
                    ) {
                        urlToOpen = URL(string: "https://tama.qaq.tw/")
                        showSafari = true
                    }
                    
                    notificationSettingsRow
                    
                    languageSettingsRow
                    
                    darkModeSettingsRow
                    
                    // Support
                    sectionHeader("その他")
                    
                    settingsRow(
                        icon: "doc.text.fill",
                        title: "利用規約"
                    ) {
                        urlToOpen = URL(string: "https://tama.qaq.tw/user-agreement")
                        showSafari = true
                    }
                    
                    settingsRow(
                        icon: "hand.raised.fill",
                        title: "プライバシーポリシー"
                    ) {
                        urlToOpen = URL(string: "https://tama.qaq.tw/policy")
                        showSafari = true
                    }
                    
                    settingsRow(
                        icon: "exclamationmark.bubble.fill",
                        title: "フィードバック"
                    ) {
                        sendFeedback()
                    }
                    
                    settingsRow(
                        icon: "star.fill",
                        title: "アプリを評価"
                    ) {
                        ratingService.requestRatingManually()
                    }
                    
                    logoutButton
                }
                
                // App Info
                appInfoSection
                    .padding(.top, 32)
            }
            .padding(.bottom, 100)
        }
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadUserData()
            notificationService.checkAuthorizationStatus()
        }
        .sheet(isPresented: $showSafari) {
            if let url = urlToOpen {
                SafariWebView(url: url)
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(isShowing: $showMailComposer)
        }
        .sheet(isPresented: $showingDarkModeSheet) {
            DarkModeSettingsView(appearanceManager: appearanceManager)
        }
    }
    
    // MARK: - User Profile Section
    private var userProfileSection: some View {
        GlassCard(variant: .elevated) {
            HStack(spacing: 16) {
                // Profile Avatar
                Text(getInitials())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    StyledText(user?.fullName ?? "ユーザー名", style: .titleMedium)
                    StyledText("@\(user?.username ?? "username")", style: .caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        StyledText(title, style: .caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }
    
    // MARK: - Settings Row
    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                StyledText(title, style: .bodyMedium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ThemeColors.Glass.light)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Notification Settings Row
    private var notificationSettingsRow: some View {
        Button {
            handleNotificationSettings()
        } label: {
            HStack {
                Image(systemName: notificationService.isAuthorized ? "bell.fill" : "bell.slash")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                StyledText("通知設定", style: .bodyMedium)
                
                Spacer()
                
                StyledText(getNotificationStatusText(), style: .caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ThemeColors.Glass.light)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Language Settings Row
    private var languageSettingsRow: some View {
        Button {
            languageService.openLanguageSettings()
        } label: {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                StyledText("言語", style: .bodyMedium)
                
                Spacer()
                
                StyledText(languageService.currentLanguage, style: .caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ThemeColors.Glass.light)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Dark Mode Settings Row
    private var darkModeSettingsRow: some View {
        Button {
            showingDarkModeSheet = true
        } label: {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                StyledText("ダークモード", style: .bodyMedium)
                
                Spacer()
                
                StyledText(getDarkModeText(), style: .caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ThemeColors.Glass.light)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Logout Button
    private var logoutButton: some View {
        Button {
            logout()
        } label: {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .foregroundColor(.red)
                    .frame(width: 24)
                
                StyledText("ログアウト", style: .bodyMedium)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(ThemeColors.Glass.light)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            StyledText("TUTnext", style: .bodyMedium)
            
            Text("バージョン \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .typography(.captionSmall)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Helper Methods
    private func loadUserData() {
        if let coreUser = userService.currentUser {
            user = LegacyUser(
                id: coreUser.userId,
                username: coreUser.userId,
                fullName: coreUser.name ?? "",
                encryptedPassword: nil,
                allKeijiMidokCnt: 0
            )
        }
    }
    
    private func getInitials() -> String {
        guard let fullName = user?.fullName else { return "?" }
        let nameParts = fullName.split(separator: "　")
        if let firstPart = nameParts.first {
            return String(firstPart.prefix(2))
        }
        return "?"
    }
    
    private func getNotificationStatusText() -> String {
        if notificationService.isAuthorized {
            return notificationService.isRegistered ? "オン" : "設定中..."
        }
        return "オフ"
    }
    
    private func getDarkModeText() -> String {
        switch appearanceManager.type {
        case .iSystem: return "システムに従う"
        case .iHight: return "ライト"
        case .iDark: return "ダーク"
        }
    }
    
    private func handleNotificationSettings() {
        if notificationService.isAuthorized && !notificationService.isRegistered {
            notificationService.registerForRemoteNotifications()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.notificationService.checkAuthorizationStatus()
                }
            }
        }
    }
    
    private func openPasswordChangeURL() {
        let url = URL(string: "https://google.tama.ac.jp/unicornidm/user/tama/password/")
        urlToOpen = url
        showSafari = true
    }
    
    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            let emailAddress = "admin@ukenn.top"
            let subject = "TUTnext アプリフィードバック"
            if let url = URL(string: "mailto:\(emailAddress)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func logout() {
        Task {
            do {
                _ = try await authService.logout()
                await MainActor.run {
                    performLocalLogout()
                }
            } catch {
                await MainActor.run {
                    performLocalLogout()
                }
            }
        }
    }
    
    private func performLocalLogout() {
        userService.clearCurrentUser()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoggedIn = false
            }
        }
    }
}

// MARK: - Dark Mode Settings View
struct DarkModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icons
                HStack(spacing: 20) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 30))
                        .foregroundColor(colorScheme == .light ? .orange : .gray)
                    
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 30))
                        .foregroundColor(colorScheme == .dark ? .blue : .gray)
                }
                .padding(.top, 20)
                
                // Options
                VStack(spacing: 12) {
                    appearanceOptionCard(
                        title: "システムに従う",
                        icon: "gear",
                        description: "デバイスの設定に合わせて自動的に切り替えます",
                        isSelected: appearanceManager.type == .iSystem
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appearanceManager.type = .iSystem
                            appearanceManager.isDarkMode = appearanceManager.getCurrentInterfaceStyle() == .dark
                        }
                    }
                    
                    appearanceOptionCard(
                        title: "ライトモード",
                        icon: "sun.max.fill",
                        description: "明るい外観を常に使用します",
                        isSelected: appearanceManager.type == .iHight
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appearanceManager.type = .iHight
                            appearanceManager.isDarkMode = false
                        }
                    }
                    
                    appearanceOptionCard(
                        title: "ダークモード",
                        icon: "moon.stars.fill",
                        description: "暗い外観を常に使用します",
                        isSelected: appearanceManager.type == .iDark
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appearanceManager.type = .iDark
                            appearanceManager.isDarkMode = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .navigationTitle("外観モード")
            .navigationBarItems(trailing: Button("完了") { dismiss() })
        }
    }
    
    private func appearanceOptionCard(title: String, icon: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    StyledText(title, style: .bodyMedium)
                        .fontWeight(.semibold)
                    StyledText(description, style: .captionSmall)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(ThemeColors.Glass.light)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        UserSettingsView(isLoggedIn: .constant(true))
    }
    .environmentObject(ThemeManager.shared)
    .environmentObject(AppearanceManager())
    .environmentObject(NotificationService.shared)
    .environmentObject(LanguageService.shared)
}
