//
//  LoadingView.swift
//  TUTnext
//
//  Glassmorphism Loading Component
//

import SwiftUI

struct LoadingView: View {
    private let message: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Glassmorphism Loading Animation
            GlassCard(variant: .elevated) {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.5)
                    
                    StyledText(message, style: .bodyMedium)
                        .foregroundColor(.secondary)
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

struct GlassLoadingIndicator: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .scaleEffect(loadingState ? 1.0 : 0.5)
                    .opacity(loadingState ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: loadingState
                    )
            }
        }
        .onAppear {
            loadingState = true
        }
    }
    
    @State private var loadingState = false
}

// MARK: - Shimmer Loading View

struct ShimmerLoadingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                GlassCard(variant: .outline) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 16)
                                .frame(maxWidth: .infinity)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 12)
                        }
                    }
                }
            }
        }
        .shimmering()
    }
}

extension View {
    func shimmering() -> some View {
        self.overlay(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: -geometry.size.width)
            }
        )
        .mask(self)
    }
}

#Preview {
    VStack {
        LoadingView()
        
        HStack {
            GlassLoadingIndicator()
            Text("読み込み中...")
                .typography(.bodyMedium)
        }
        .padding()
        
        ShimmerLoadingView()
            .frame(height: 300)
    }
    .environmentObject(ThemeManager.shared)
}
