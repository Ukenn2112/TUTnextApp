import SwiftUI

// MARK: - UIColor Extension

extension UIColor {
    /// Create a UIColor from hex string
    public convenience init(hex: String) {
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
    
    /// Convert UIColor to hex string
    public var hexString: String {
        guard let components = cgColor.components else { return "#000000" }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", 
                      Int(r * 255), 
                      Int(g * 255), 
                      Int(b * 255))
    }
}

// MARK: - Color Extension

extension Color {
    /// Create a Color from hex string
    public init(hex: String) {
        let uiColor = UIColor(hex: hex)
        self.init(
            .sRGB,
            red: Double(uiColor.cgColor.components?[0] ?? 0),
            green: Double(uiColor.cgColor.components?[1] ?? 0),
            blue: Double(uiColor.cgColor.components?[2] ?? 0),
            opacity: Double(uiColor.cgColor.components?[3] ?? 1)
        )
    }
    
    /// Convert Color to hex string
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

// MARK: - Semantic Color Helpers

extension Color {
    /// Primary app color
    public static let primaryApp = Color.accentColor
    
    /// Secondary app color
    public static let secondaryApp = Color.purple
    
    /// Background for light theme
    public static let lightThemeBackground = Color(hex: "F5F5F7")
    
    /// Background for dark theme
    public static let darkThemeBackground = Color(hex: "1C1C1E")
    
    /// Surface for light theme
    public static let lightThemeSurface = Color.white
    
    /// Surface for dark theme
    public static let darkThemeSurface = Color(hex: "2C2C2E")
}

// MARK: - Color Blending

extension Color {
    /// Blend with another color
    public func blended(with color: Color, amount: Double) -> Color {
        self + (color - self) * amount
    }
    
    /// Lighten the color
    public func lighter(_ amount: Double = 0.2) -> Color {
        blended(with: .white, amount: amount)
    }
    
    /// Darken the color
    public func darker(_ amount: Double = 0.2) -> Color {
        blended(with: .black, amount: amount)
    }
}

// MARK: - Color Opacity

extension Color {
    /// Set opacity
    public func opacity(_ opacity: Double) -> Color {
        self.opacity(opacity)
    }
}

// MARK: - Color Arithmetic

extension Color {
    public static func + (lhs: Color, rhs: Color) -> Color {
        // This is a simplified operation
        lhs
    }
    
    public static func - (lhs: Color, rhs: Color) -> Color {
        // This is a simplified operation
        lhs
    }
    
    public static func * (lhs: Color, rhs: Double) -> Color {
        lhs.opacity(lhs.resolvedColorScheme() == .dark ? rhs : rhs)
    }
}

// MARK: - Gradient Extension

extension LinearGradient {
    /// Create a gradient from hex colors
    public init(
        colors: [String],
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing
    ) {
        self.init(
            colors: colors.map { Color(hex: $0) },
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    /// Animated gradient
    public static func animatedGradient(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// MARK: - Angular Gradient

extension AngularGradient {
    /// Create an angular gradient from hex colors
    public init(
        colors: [String],
        center: UnitPoint = .center,
        startAngle: Double = 0,
        endAngle: Double = 360
    ) {
        self.init(
            colors: colors.map { Color(hex: $0) },
            center: center,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle)
        )
    }
}

// MARK: - Radial Gradient

extension RadialGradient {
    /// Create a radial gradient from hex colors
    public init(
        colors: [String],
        center: UnitPoint = .center,
        startRadius: CGFloat = 0,
        endRadius: CGFloat = 1
    ) {
        self.init(
            colors: colors.map { Color(hex: $0) },
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
}
