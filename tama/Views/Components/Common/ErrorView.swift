//
//  ErrorView.swift
//  TUTnext
//
//  Glassmorphism Error Component
//

import SwiftUI

struct ErrorView: View {
    private let title: String
    private let message: String
    private let retryAction: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(
        title: String = "エラーが発生しました",
        message: String,
        retryAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    StyledText(title, style: .titleMedium)
                    
                    StyledText(message, style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    GlassButton("再読み込み", variant: .primary) {
                        retryAction()
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
    }
}

struct NetworkErrorView: View {
    private let retryAction: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(retryAction: @escaping () -> Void) {
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    StyledText("ネットワークエラー", style: .titleMedium)
                    
                    StyledText("接続状況を確認し、もう一度お試しください。", style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    GlassButton("再試行", variant: .secondary) {
                        retryAction()
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
    }
}

struct ServerErrorView: View {
    private let errorCode: String?
    private let retryAction: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(errorCode: String? = nil, retryAction: @escaping () -> Void) {
        self.errorCode = errorCode
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.8))
                    
                    StyledText("サーバーエラー", style: .titleMedium)
                    
                    if let code = errorCode {
                        StyledText("エラーコード: \(code)", style: .caption)
                            .foregroundColor(.secondary)
                    }
                    
                    StyledText("暫く経ってから再度お試しください。", style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    GlassButton("再試行", variant: .danger) {
                        retryAction()
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
    }
}

struct UnauthorizedErrorView: View {
    private let message: String
    private let onRelogin: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(message: String = "セッションが無効になりました。", onRelogin: @escaping () -> Void) {
        self.message = message
        self.onRelogin = onRelogin
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    StyledText("認証エラー", style: .titleMedium)
                    
                    StyledText(message, style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    GlassButton("再ログイン", variant: .primary) {
                        onRelogin()
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    VStack {
        ErrorView(message: "データの読み込みに失敗しました。") {
            print("Retry tapped")
        }
        
        NetworkErrorView {
            print("Retry tapped")
        }
        
        ServerErrorView(errorCode: "500") {
            print("Retry tapped")
        }
        
        UnauthorizedErrorView {
            print("Relogin tapped")
        }
    }
    .environmentObject(ThemeManager.shared)
}
