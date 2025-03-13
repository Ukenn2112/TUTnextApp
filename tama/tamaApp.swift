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
    
    // AppDelegateを使用
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearanceManager)
                .environmentObject(notificationService)
                .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
                .onAppear {
                    appearanceManager.startObservingSystemAppearance()
                    // アプリ起動時に通知権限をチェック
                    notificationService.checkAuthorizationStatus()
                }
        }
    }
}
