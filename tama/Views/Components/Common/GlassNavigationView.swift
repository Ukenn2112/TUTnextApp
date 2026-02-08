//
//  GlassNavigationView.swift
//  TUTnext
//
//  Glassmorphism Navigation Wrapper
//

import SwiftUI

struct GlassNavigationView<Content: View>: View {
    private let content: Content
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            content
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    GlassNavigationView {
        Text("Content")
            .environmentObject(ThemeManager.shared)
    }
}
