import Foundation
import SwiftUI

// MARK: - View Extensions

extension View {
    /// Apply conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply conditional modifier with else
    @ViewBuilder
    func ifElse<IfContent: View, ElseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> IfContent,
        else elseTransform: (Self) -> ElseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
    /// Wrap in a loading overlay
    func loading(_ isLoading: Bool) -> some View {
        ZStack {
            self
                .disabled(isLoading)
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
            }
        }
    }
    
    /// Apply frame with optional parameters
    func frame(size: CGSize? = nil, width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        var modifiedFrame = self.frame()
        if let width = width {
            modifiedFrame = modifiedFrame.frame(width: width)
        }
        if let height = height {
            modifiedFrame = modifiedFrame.frame(height: height)
        }
        if let size = size {
            modifiedFrame = modifiedFrame.frame(width: size.width, height: size.height)
        }
        return modifiedFrame
    }
}

// MARK: - Color Extensions

extension Color {
    /// App primary color
    static let appPrimary = Color(red: 0.0 / 255.0, green: 98.0 / 255.0, blue: 196.0 / 255.0)
    
    /// App secondary color
    static let appSecondary = Color(red: 0.0 / 255.0, green: 147.0 / 255.0, blue: 231.0 / 255.0)
    
    /// App accent color
    static let appAccent = Color(red: 255.0 / 255.0, green: 199.0 / 255.0, blue: 44.0 / 255.0)
    
    /// Success color
    static let success = Color.green
    
    /// Warning color
    static let warning = Color.orange
    
    /// Error color
    static let error = Color.red
    
    /// Initialize from hex string
    init(hex: String) {
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
}

// MARK: - Font Extensions

extension Font {
    /// Custom app font
    static let appTitle = Font.system(size: 24, weight: .bold)
    static let appHeadline = Font.system(size: 20, weight: .semibold)
    static let appBody = Font.system(size: 16, weight: .regular)
    static let appCaption = Font.system(size: 12, weight: .regular)
    
    /// Large title for iOS
    static let largeTitle = Font.system(size: 34, weight: .bold)
    
    /// Title for sections
    static let title = Font.system(size: 20, weight: .semibold)
}

// MARK: - EdgeInsets Extensions

extension EdgeInsets {
    /// Standard padding values
    static let standard = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    static let small = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    static let large = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
    static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

// MARK: - Shape Extensions

extension Shape {
    /// Add corner radius
    func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .circular) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: style))
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Standard spring animation
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Smooth ease-in-out animation
    static let smooth = Animation.easeInOut(duration: 0.25)
    
    /// Quick tap animation
    static let tap = Animation.easeInOut(duration: 0.1)
}
