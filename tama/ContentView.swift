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
            
            // URLスキームからのディープリンク処理を確認
            processInitialURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HandleURLScheme"))) { notification in
            if let url = notification.object as? URL {
                handleDeepLink(url: url)
            }
        }
        // アプリ全体のダークモード設定
        .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
        .onChange(of: appearanceManager.isDarkMode) { oldValue, newValue in
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
    
    // アプリ起動時に初期URLを処理
    private func processInitialURL() {
        if let path = AppDelegate.shared.getPathComponent() {
            print("Processing initial URL path: \(path)")
            // ログインしていない場合は一旦スキップ（ログイン後に処理される）
            guard isLoggedIn else { 
                print("User not logged in, skipping URL processing")
                return 
            }
            
            navigateBasedOnPath(path)
            
            // URLによる遷移が完了したらリセット
            AppDelegate.shared.resetURLProcessing()
        }
    }
    
    // URLスキームの処理
    private func handleDeepLink(url: URL) {
        guard isLoggedIn else { return } // ログインしていない場合は無視
        
        print("Handling deep link: \(url.absoluteString)")
        // ホスト部分を取得（例：tama://timetable なら "timetable"）
        let path = url.host ?? ""
        print("URL path component: \(path)")
        navigateBasedOnPath(path)
    }
    
    // パスに基づいてタブに遷移
    private func navigateBasedOnPath(_ path: String) {
        print("Navigating based on path: \(path)")
        
        switch path {
        case "timetable":
            print("Switching to timetable tab")
            selectedTab = 1
        case "assignment":
            print("Switching to assignment tab")
            selectedTab = 2
        case "bus":
            print("Switching to bus tab")
            selectedTab = 0
            // URLからバスのパラメータを取得して通知を送信
            let route = AppDelegate.shared.getQueryValue(for: "route")
            let schedule = AppDelegate.shared.getQueryValue(for: "schedule")
            
            print("Bus parameters - route: \(route ?? "nil"), schedule: \(schedule ?? "nil")")
            
            if route != nil || schedule != nil {
                // パラメータをNotificationCenterを通じてBusScheduleViewに送信
                let userInfo: [String: Any?] = ["route": route, "schedule": schedule]
                NotificationCenter.default.post(
                    name: Notification.Name("BusParametersFromURL"),
                    object: nil,
                    userInfo: userInfo as [AnyHashable : Any]
                )
            }
        default:
            print("Unknown path: \(path)")
            break
        }
    }
}

#Preview() {
    ContentView()
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
}
