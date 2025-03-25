//
//  tamaApp.swift
//  tama
//
//  Created by 维安雨轩 on 2025/02/27.
//

import SwiftUI
import SwiftData

@main
struct tamaApp: App {
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var languageService = LanguageService.shared
    
    // AppDelegateを使用
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearanceManager)
                .environmentObject(notificationService)
                .environmentObject(languageService)
                .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
                .onAppear {
                    print("tamaApp: Application appeared")
                    appearanceManager.startObservingSystemAppearance()
                    // アプリ起動時に通知権限をチェック
                    notificationService.checkAuthorizationStatus()
                }
                // URLスキームを処理
                .onOpenURL { url in
                    print("tamaApp: Received openURL: \(url)")
                    // AppDelegateにURLを処理させる
                    let _ = AppDelegate.shared.handleURL(url)
                }
        }
    }
}
