//
//  TamaApp.swift
//  tama
//
//  Created by 维安雨轩 on 2025/02/27.
//

import SwiftData
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
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = SharedModelContainer.shared

    // MARK: - ボディ

    var body: some Scene {
        WindowGroup {
            rootView
                .appearanceOverride(appearanceManager)
                .appStoreReviewRequest(ratingService)
                .modelContainer(modelContainer)
                .environmentObject(appearanceManager)
                .environmentObject(notificationService)
                .environmentObject(languageService)
                .environmentObject(ratingService)
                .environmentObject(GoogleOAuthService.shared)
                .onAppear {
                    notificationService.checkAuthorizationStatus()
                    ratingService.onAppLaunch()
                }
                .onOpenURL { url in
                    _ = AppDelegate.shared.handleURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task { @MainActor in
                            await LiveActivityScheduler.shared.syncLiveActivity()
                        }
                    case .background:
                        LiveActivityScheduler.shared.pauseForegroundTimer()
                    default:
                        break
                    }
                }
        }
    }

    // MARK: - サブビュー

    /// ルートビュー（DEBUGビルドでは計測用オーバーレイを重ねられるようにする）
    private var rootView: some View {
        #if DEBUG
        ContentView().duoMetricsOverlay()
        #else
        ContentView()
        #endif
    }
}
