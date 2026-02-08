//
//  WelcomeView.swift
//  TUTnext
//
//  Glassmorphism Welcome View
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Glassmorphism Background
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    StyledText("TUTnext", style: .headlineLarge)
                    
                    StyledText("多摩大学生のためのスマートアプリ", style: .bodyMedium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Features
                VStack(spacing: 24) {
                    featureRow(
                        icon: "calendar",
                        title: "時間割管理",
                        description: "授業時間・サークルを一元管理"
                    )
                    
                    featureRow(
                        icon: "bus.fill",
                        title: "バス時刻表",
                        description: "リアルタイム運行情報を確認"
                    )
                    
                    featureRow(
                        icon: "doc.text.fill",
                        title: "課題管理",
                        description: "提出期限を見逃さない"
                    )
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Get Started Button
                GlassButton("始める", variant: .primary) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoggedIn = true
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        GlassCard(variant: .elevated) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    StyledText(title, style: .titleMedium)
                    StyledText(description, style: .caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(isLoggedIn: .constant(false))
        .environmentObject(ThemeManager.shared)
}
