import SwiftUI

// MARK: - Design System Entry Point
@main
struct TUTnextDesignSystemApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

// MARK: - Content View for Demo
struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GlassNavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Theme Toggle
                    GlassCard {
                        HStack {
                            Text("Current Theme:")
                                .foregroundStyle(.secondary)
                            Text(themeManager.currentThemeName)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: { themeManager.toggleTheme() }) {
                                Text("Toggle Theme")
                                    .font(.caption)
                            }
                        }
                        .padding()
                    }
                    
                    // Typography Demo
                    Text("Typography System")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Headline Large")
                            .typography(.headlineLarge)
                        Text("Headline Medium")
                            .typography(.headlineMedium)
                        Text("Title Large")
                            .typography(.titleLarge)
                        Text("Body Large")
                            .typography(.bodyLarge)
                        Text("Body Medium")
                            .typography(.bodyMedium)
                        Text("Label Large")
                            .typography(.labelLarge)
                    }
                    .padding(.horizontal)
                    
                    // Button Variants
                    Text("Button Components")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        GlassButton("Primary Button", variant: .primary) {
                            print("Primary tapped")
                        }
                        
                        GlassButton("Secondary Button", variant: .secondary) {
                            print("Secondary tapped")
                        }
                        
                        GlassButton("Ghost Button", variant: .ghost) {
                            print("Ghost tapped")
                        }
                        
                        GlassButton("Disabled", variant: .primary, isEnabled: false) {
                            print("Disabled tapped")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Card Variants
                    Text("Card Components")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        GlassCard {
                            Text("Elevated Card")
                                .font(.headline)
                        }
                        
                        GlassCard(variant: .bordered) {
                            Text("Bordered Card")
                                .font(.headline)
                        }
                        
                        GlassCard(variant: .outline) {
                            Text("Outline Card")
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Toast Demo
                    GlassButton("Show Toast") {
                        ToastManager.shared.show(
                            message: "This is a glass toast notification!",
                            type: .success
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 100)
            }
            .background(
                LinearGradient(
                    colors: [
                        ThemeColors.Gradient.startGradient(for: themeManager.currentTheme),
                        ThemeColors.Gradient.endGradient(for: themeManager.currentTheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
