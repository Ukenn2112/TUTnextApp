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
                        
                        Text("TODO: 課題")
                            .tag(2)
                        
                        Text("TODO: 揭示板")
                            .tag(3)
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
    }
    
    // ログイン状態を確認
    private func checkLoginStatus() {
        // UserServiceからユーザー情報を取得
        let user = UserService.shared.getCurrentUser()
        // ユーザー情報があればログイン状態とする
        isLoggedIn = user != nil
    }
}

#Preview {
    ContentView()
}
