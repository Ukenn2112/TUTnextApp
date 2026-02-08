import SwiftUI
import Combine

// MARK: - Theme Manager

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: Theme {
        didSet {
            saveTheme()
        }
    }
    
    @Published public var useSystemTheme: Bool = true {
        didSet {
            saveUseSystemTheme()
            updateColorScheme()
        }
    }
    
    public var colorScheme: ColorScheme? {
        useSystemTheme ? nil : currentTheme.colorScheme
    }
    
    public var currentThemeName: String {
        useSystemTheme ? "System (\(currentTheme.displayName))" : currentTheme.displayName
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.currentTheme = ThemeManager.loadTheme()
        self.useSystemTheme = ThemeManager.loadUseSystemTheme()
        
        setupColorSchemeObserver()
    }
    
    private func setupColorSchemeObserver() {
        NotificationCenter.default.publisher(for: .colorSchemeChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateColorScheme()
            }
            .store(in: &cancellables)
    }
    
    public func setTheme(_ theme: Theme) {
        currentTheme = theme
    }
    
    public func toggleTheme() {
        guard !useSystemTheme else {
            useSystemTheme = false
            currentTheme = currentTheme == .light ? .dark : .light
            return
        }
        
        currentTheme = currentTheme == .light ? .dark : .light
    }
    
    public func cycleTheme() {
        let allThemes = Theme.allCases
        guard let currentIndex = allThemes.firstIndex(of: currentTheme) else { return }
        let nextIndex = (currentIndex + 1) % allThemes.count
        currentTheme = allThemes[nextIndex]
    }
    
    public func useSystemThemeSetting() {
        useSystemTheme = true
    }
    
    private func updateColorScheme() {
        // Color scheme is automatically applied via .preferredColorScheme modifier
    }
    
    // MARK: - Persistence
    
    private static func loadTheme() -> Theme {
        guard let themeName = UserDefaults.standard.string(forKey: "tutnext_theme"),
              let theme = Theme(rawValue: themeName) else {
            return .light
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "tutnext_theme")
    }
    
    private static func loadUseSystemTheme() -> Bool {
        return !UserDefaults.standard.bool(forKey: "tutnext_use_system_theme_disabled")
    }
    
    private func saveUseSystemTheme() {
        UserDefaults.standard.set(!useSystemTheme, forKey: "tutnext_use_system_theme_disabled")
    }
}

// MARK: - Color Scheme Notification

extension Notification.Name {
    public static let colorSchemeChange = Notification.Name("colorSchemeDidChange")
}

// MARK: - View Extension

public extension View {
    func applyGlassTheme(_ theme: Theme) -> some View {
        self.background(
            LinearGradient(
                colors: [
                    ThemeColors.Gradient.startGradient(for: theme),
                    ThemeColors.Gradient.endGradient(for: theme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Theme Manager Demo")
            .font(.title)
            .padding()
        
        Button("Cycle Theme") {
            ThemeManager.shared.cycleTheme()
        }
        
        Button("Toggle System Theme") {
            ThemeManager.shared.useSystemTheme.toggle()
        }
    }
    .environmentObject(ThemeManager.shared)
}
