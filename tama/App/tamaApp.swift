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

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - ボディ

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environmentObject(appearanceManager)
                .environmentObject(notificationService)
                .environmentObject(languageService)
                .environmentObject(ratingService)
                .environmentObject(GoogleOAuthService.shared)
                .onAppear {
                    appearanceManager.applyAppearance()
                    notificationService.checkAuthorizationStatus()
                    ratingService.onAppLaunch()
                }
                .onOpenURL { url in
                    _ = AppDelegate.shared.handleURL(url)
                }
        }
    }
}
