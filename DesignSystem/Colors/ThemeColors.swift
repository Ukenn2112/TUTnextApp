import SwiftUI

// MARK: - Theme Colors

public enum ThemeColors {
    
    // MARK: - Glass Colors
    
    public enum Glass {
        /// Ultra-light glass background
        public static let ultraLight = Color.white.opacity(0.25)
        /// Light glass background
        public static let light = Color.white.opacity(0.35)
        /// Medium glass background
        public static let medium = Color.white.opacity(0.50)
        /// Dark glass background
        public static let dark = Color.white.opacity(0.65)
        /// Heavy glass background
        public static let heavy = Color.white.opacity(0.80)
        
        /// Light glass border
        public static let borderLight = Color.white.opacity(0.30)
        /// Dark glass border
        public static let borderDark = Color.white.opacity(0.20)
        
        /// Glass highlight color
        public static let highlight = Color.white.opacity(0.45)
        /// Glass shadow color
        public static let shadow = Color.black.opacity(0.15)
        
        /// iOS 17 Material blur effect colors
        public static let materialUltraThin = Color.white.opacity(0.1)
        public static let materialThin = Color.white.opacity(0.2)
        public static let materialMedium = Color.white.opacity(0.3)
        public static let materialThick = Color.white.opacity(0.4)
        public static let materialUltraThick = Color.white.opacity(0.5)
    }
    
    // MARK: - Gradients
    
    public enum Gradient {
        // MARK: - Light Theme Gradients
        
        public static func startGradient(for theme: Theme) -> Color {
            switch theme {
            case .light:
                return Color(hex: "E8F4FD")
            case .dark:
                return Color(hex: "1A1A2E")
            case .midnight:
                return Color(hex: "0F0F23")
            case .blush:
                return Color(hex: "FFF5F5")
            case .forest:
                return Color(hex: "F0F7F4")
            }
        }
        
        public static func endGradient(for theme: Theme) -> Color {
            switch theme {
            case .light:
                return Color(hex: "D4E8F7")
            case .dark:
                return Color(hex: "16213E")
            case .midnight:
                return Color(hex: "1A1A2E")
            case .blush:
                return Color(hex: "FFE5E5")
            case .forest:
                return Color(hex: "E8F5E9")
            }
        }
        
        // Accent Gradients
        public static let primaryGradient = LinearGradient(
            colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let glassGradient = LinearGradient(
            colors: [Glass.ultraLight, Glass.light],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let shimmerGradient = LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.5),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        // Animated gradient for loading states
        public static var animatedGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(hex: "667eea").opacity(0.8),
                    Color(hex: "764ba2").opacity(0.8),
                    Color(hex: "f093fb").opacity(0.8),
                    Color(hex: "f5576c").opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Accent Colors
    
    public enum Accent {
        public static let primary = Color.accentColor
        public static let secondary = Color.purple
        public static let tertiary = Color.pink
        public static let quaternary = Color.teal
        
        // Accent Color Palette
        public static let palette: [Color] = [
            .blue, .purple, .pink, .red, .orange, 
            .yellow, .green, .teal, .cyan, .indigo
        ]
    }
    
    // MARK: - Semantic Colors
    
    public enum Semantic {
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue
        
        // Toast Colors
        public enum Toast {
            public static let successBackground = Color.green.opacity(0.9)
            public static let warningBackground = Color.orange.opacity(0.9)
            public static let errorBackground = Color.red.opacity(0.9)
            public static let infoBackground = Color.blue.opacity(0.9)
            
            public static let successText = Color.white
            public static let warningText = Color.white
            public static let errorText = Color.white
            public static let infoText = Color.white
        }
        
        // Interactive States
        public enum State {
            public static let disabled = Color.gray.opacity(0.5)
            public static let pressed = Color.black.opacity(0.1)
            public static let hovered = Color.white.opacity(0.1)
        }
    }
    
    // MARK: - Neutral Colors
    
    public enum Neutral {
        public static let gray50 = Color(hex: "FAFAFA")
        public static let gray100 = Color(hex: "F5F5F5")
        public static let gray200 = Color(hex: "EEEEEE")
        public static let gray300 = Color(hex: "E0E0E0")
        public static let gray400 = Color(hex: "BDBDBD")
        public static let gray500 = Color(hex: "9E9E9E")
        public static let gray600 = Color(hex: "757575")
        public static let gray700 = Color(hex: "616161")
        public static let gray800 = Color(hex: "424242")
        public static let gray900 = Color(hex: "212121")
        
        // Light Theme Neutrals
        public static let lightBackground = Color.white
        public static let lightSurface = Color(hex: "F8FAFB")
        public static let lightBorder = Color.gray.opacity(0.2)
        public static let lightText = Color.black.opacity(0.87)
        public static let lightTextSecondary = Color.black.opacity(0.6)
        
        // Dark Theme Neutrals
        public static let darkBackground = Color(hex: "121212")
        public static let darkSurface = Color(hex: "1E1E1E")
        public static let darkBorder = Color.white.opacity(0.1)
        public static let darkText = Color.white.opacity(0.87)
        public static let darkTextSecondary = Color.white.opacity(0.6)
    }
}

// MARK: - Theme Enum

public enum Theme: String, CaseIterable, Identifiable, Codable {
    case light
    case dark
    case midnight
    case blush
    case forest
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .midnight: return "Midnight"
        case .blush: return "Blush"
        case .forest: return "Forest"
        }
    }
    
    public var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .midnight: return "moon.stars.fill"
        case .blush: return "heart.fill"
        case .forest: return "leaf.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .midnight: return .dark
        case .blush: return .light
        case .forest: return .light
        }
    }
    
    public var glassOpacity: Double {
        switch self {
        case .light: return 0.35
        case .dark: return 0.45
        case .midnight: return 0.50
        case .blush: return 0.30
        case .forest: return 0.35
        }
    }
}

// MARK: - Color Extension

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public var hex: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", 
                      Int(r * 255), 
                      Int(g * 255), 
                      Int(b * 255))
    }
}
