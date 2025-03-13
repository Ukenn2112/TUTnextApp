//
//  ContentView.swift
//  tama
//
//  Created by 维安雨轩 on 2025/02/27.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var isLoggedIn = false
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    HeaderView(selectedTab: $selectedTab, isLoggedIn: $isLoggedIn)
                    
                    TabView(selection: $selectedTab) {
                        BusScheduleView()
                            .tag(0)
                        
                        TimetableView(isLoggedIn: $isLoggedIn)
                            .tag(1)
                        
                        AssignmentView(isLoggedIn: $isLoggedIn)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .edgesIgnoringSafeArea(.bottom)
                    
                    TabBarView(selectedTab: $selectedTab)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoggedIn)
        .onAppear {
            // アプリ起動時にログイン状態を確認
            checkLoginStatus()
        }
        // アプリ全体のダークモード設定
        .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
        .onChange(of: appearanceManager.isDarkMode) { newValue in
            print("ContentView detected isDarkMode change: \(newValue)")
        }
        // 通知センターでの変更監視も追加
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppearanceDidChangeNotification"))) { _ in
            // 通知を受け取ったら強制的に再描画
            print("ContentView received appearance change notification")
        }
    }
    
    // ログイン状態を確認
    private func checkLoginStatus() {
        // UserServiceからユーザー情報を取得
        let user = UserService.shared.getCurrentUser()
        // ユーザー情報があればログイン状態とする
        isLoggedIn = user != nil
    }
}

#Preview() {
    ContentView()
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
}
