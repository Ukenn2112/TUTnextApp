//
//  TamaApp.swift
//  tama
//
//  Created by 维安雨轩 on 2025/02/27.
//

import SwiftUI

/// アプリケーションのエントリーポイント
@main
struct TamaApp: App {

    // MARK: - プロパティ

    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var languageService = LanguageService.shared
    @StateObject private var ratingService = RatingService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - ボディ

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearanceManager)
                .environmentObject(notificationService)
                .environmentObject(languageService)
                .environmentObject(ratingService)
                .environmentObject(GoogleOAuthService.shared)
                .preferredColorScheme(appearanceManager.colorSchemeOverride)
                .onAppear {
                    appearanceManager.startObservingSystemAppearance()
                    notificationService.checkAuthorizationStatus()
                    ratingService.onAppLaunch()
                }
                .onOpenURL { url in
                    _ = AppDelegate.shared.handleURL(url)
                }
        }
    }
}
