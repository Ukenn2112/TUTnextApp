//
//  EmptyStateView.swift
//  TUTnext
//
//  Glassmorphism Empty State Component
//

import SwiftUI

struct EmptyStateView: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(
        icon: String = "checkmark.circle",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundColor(.green.opacity(0.8))
                    
                    StyledText(title, style: .titleLarge)
                    
                    StyledText(message, style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let actionTitle = actionTitle, let action = action {
                        GlassButton(actionTitle, variant: .primary) {
                            action()
                        }
                        .padding(.top, 8)
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

struct EmptyTimetableView: View {
    private let onAddCourse: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(onAddCourse: @escaping () -> Void) {
        self.onAddCourse = onAddCourse
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    StyledText("時間割が登録されていません", style: .titleLarge)
                    
                    StyledText("履修登録を行うことで時間割が表示されます。", style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    GlassButton("履修登録サイトへ", variant: .primary) {
                        onAddCourse()
                    }
                    .padding(.top, 8)
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

struct EmptyAssignmentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green.opacity(0.8))
                    
                    StyledText("課題はありません", style: .titleLarge)
                    
                    StyledText("現在提出すべき課題はありません。", style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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

struct EmptyBusScheduleView: View {
    private let message: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(message: String = "本日の運行は終了しています") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.purple.opacity(0.8))
                    
                    StyledText("運行終了", style: .titleLarge)
                    
                    StyledText(message, style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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

struct EmptySearchResultView: View {
    private let query: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(query: String) {
        self.query = query
    }
    
    var body: some View {
        VStack(spacing: 24) {
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    StyledText("検索結果が見つかりません", style: .titleMedium)
                    
                    StyledText("「\(query)」に一致する結果は見つかりませんでした。", style: .bodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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
        EmptyStateView(
            icon: "tray",
            title: "データなし",
            message: "表示するデータがありません。"
        )
        
        EmptyTimetableView {
            print("Add course")
        }
        
        EmptyAssignmentView()
        
        EmptyBusScheduleView()
        
        EmptySearchResultView(query: "テスト")
    }
    .environmentObject(ThemeManager.shared)
}
