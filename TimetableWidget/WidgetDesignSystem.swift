//
//  WidgetDesignSystem.swift
//  TimetableWidget
//
//  Simplified Design System for Widget Extensions
//

import Foundation
import SwiftUI

// MARK: - Theme Colors

public enum WidgetThemeColors {
    
    public enum Semantic {
        public static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
        public static let warning = Color(red: 1.0, green: 0.8, blue: 0.0)
        public static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
        public static let info = Color(red: 0.3, green: 0.6, blue: 1.0)
    }
    
    public enum Gradient {
        public static let startGradient = Color(red: 0.95, green: 0.95, blue: 1.0)
        public static let endGradient = Color(red: 0.85, green: 0.90, blue: 1.0)
    }
}

// MARK: - Glass Effect

public struct WidgetGlassEffect: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat
    let cornerRadius: CGFloat
    
    public init(opacity: Double = 0.3, blurRadius: CGFloat = 20, cornerRadius: CGFloat = 16) {
        self.opacity = opacity
        self.blurRadius = blurRadius
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

public extension View {
    func widgetGlassEffect(opacity: Double = 0.3, blurRadius: CGFloat = 20, cornerRadius: CGFloat = 16) -> some View {
        modifier(WidgetGlassEffect(opacity: opacity, blurRadius: blurRadius, cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Background

public struct WidgetGlassBackground: View {
    let opacity: Double
    let blurRadius: CGFloat
    let saturation: Double
    let borderOpacity: Double
    let cornerRadius: CGFloat
    
    public init(
        opacity: Double = 0.3,
        blurRadius: CGFloat = 20,
        saturation: Double = 1.5,
        borderOpacity: Double = 0.3,
        cornerRadius: CGFloat = 16
    ) {
        self.opacity = opacity
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.borderOpacity = borderOpacity
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Course Color Palette

public enum WidgetCourseColorPalette {
    private static let colors: [Color] = [
        .clear,
        Color(red: 1.0, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 0.9, blue: 0.8),
        Color(red: 1.0, green: 1.0, blue: 0.8),
        Color(red: 0.9, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 1.0),
        Color(red: 1.0, green: 0.8, blue: 0.9),
        Color(red: 0.9, green: 0.8, blue: 1.0),
        Color(red: 0.8, green: 0.9, blue: 1.0),
        Color(red: 1.0, green: 0.9, blue: 1.0),
    ]
    
    public static func getColor(for index: Int) -> Color {
        guard index >= 0 && index < colors.count else {
            return colors[0]
        }
        return colors[index]
    }
}
