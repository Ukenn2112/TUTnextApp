import SwiftUI

// MARK: - Glass Effect Modifier

/// A modifier that applies glassmorphism effect to views
public struct GlassEffect: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    private let opacity: Double
    private let blurRadius: CGFloat
    private let saturation: Double
    private let borderOpacity: Double
    private let cornerRadius: CGFloat
    
    public init(
        opacity: Double? = nil,
        blurRadius: CGFloat = 20,
        saturation: Double = 1.5,
        borderOpacity: Double = 0.3,
        cornerRadius: CGFloat = 16
    ) {
        self.opacity = opacity ?? themeManager.currentTheme.glassOpacity
        self.blurRadius = blurRadius
        self.saturation = saturation
        self.borderOpacity = borderOpacity
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                GlassBackground(
                    opacity: opacity,
                    blurRadius: blurRadius,
                    saturation: saturation,
                    borderOpacity: borderOpacity,
                    cornerRadius: cornerRadius
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Background

public struct GlassBackground: View {
    private let opacity: Double
    private let blurRadius: CGFloat
    private let saturation: Double
    private let borderOpacity: Double
    private let cornerRadius: CGFloat
    
    public init(
        opacity: Double,
        blurRadius: CGFloat,
        saturation: Double,
        borderOpacity: Double,
        cornerRadius: CGFloat
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
            .environment(\.colorScheme, .light)
            .blur(radius: blurRadius)
            .saturation(saturation)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Material Blur View (iOS 17+)

#if os(iOS)
import UIKit

/// iOS 17+ Material Blur View wrapper
public struct MaterialBlurView: UIViewRepresentable {
    private let style: UIBlurEffect.Style
    private let intensity: CGFloat
    
    public init(style: UIBlurEffect.Style = .systemMaterial, intensity: CGFloat = 0.5) {
        self.style = style
        self.intensity = intensity
    }
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        let blurView = UIVisualEffectView(effect: nil)
        return blurView
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        let effect = UIBlurEffect(style: style)
        let intensityEffect = UIVibrancyEffect(blurEffect: effect)
        
        UIView.animate(withDuration: 0.3) {
            uiView.effect = intensityEffect
        }
    }
}
#endif

// MARK: - Glass View Modifier

/// A convenient view modifier for applying glassmorphism
public struct GlassView: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    private let opacity: Double
    private let blurRadius: CGFloat
    private let cornerRadius: CGFloat
    private let shadowStyle: ShadowStyle
    
    public enum ShadowStyle {
        case none
        case soft
        case medium
        case strong
        case glow
    }
    
    public init(
        opacity: Double? = nil,
        blurRadius: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        shadow: ShadowStyle = .soft
    ) {
        self.opacity = opacity ?? themeManager.currentTheme.glassOpacity
        self.blurRadius = blurRadius
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadow
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Glass layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                        .blur(radius: blurRadius)
                        .opacity(opacity)
                    
                    // Border gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(radius: shadowRadius, x: shadowX, y: shadowY)
    }
    
    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .none: return 0
        case .soft: return 8
        case .medium: return 16
        case .strong: return 24
        case .glow: return 30
        }
    }
    
    private var shadowX: CGFloat {
        switch shadowStyle {
        case .none: return 0
        case .soft: return 0
        case .medium: return 0
        case .strong: return 0
        case .glow: return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch shadowStyle {
        case .none: return 0
        case .soft: return 4
        case .medium: return 8
        case .strong: return 12
        case .glow: return 0
        }
    }
}

public extension View {
    func glass(
        opacity: Double? = nil,
        blurRadius: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        shadow: GlassView.ShadowStyle = .soft
    ) -> some View {
        modifier(GlassView(opacity: opacity, blurRadius: blurRadius, cornerRadius: cornerRadius, shadow: shadow))
    }
    
    func glassEffect(
        opacity: Double? = nil,
        blurRadius: CGFloat = 20,
        saturation: Double = 1.5,
        borderOpacity: Double = 0.3,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(GlassEffect(opacity: opacity, blurRadius: blurRadius, saturation: saturation, borderOpacity: borderOpacity, cornerRadius: cornerRadius))
    }
}

// MARK: - Shadow Utilities

public enum GlassShadows {
    /// Soft ambient shadow
    public static let soft = Shadow(
        color: Color.black.opacity(0.1),
        radius: 8,
        x: 0,
        y: 4
    )
    
    /// Medium ambient shadow
    public static let medium = Shadow(
        color: Color.black.opacity(0.15),
        radius: 16,
        x: 0,
        y: 8
    )
    
    /// Strong ambient shadow
    public static let strong = Shadow(
        color: Color.black.opacity(0.2),
        radius: 24,
        x: 0,
        y: 12
    )
    
    /// Glow effect for buttons
    public static let glow = Shadow(
        color: Color.accentColor.opacity(0.4),
        radius: 20,
        x: 0,
        y: 0
    )
    
    /// Inner highlight shadow
    public static let innerHighlight = Shadow(
        color: Color.white.opacity(0.3),
        radius: 2,
        x: 0,
        y: -1
    )
}

// MARK: - Inner Glow Modifier

public struct InnerGlow: ViewModifier {
    private let color: Color
    private let intensity: Double
    
    public init(color: Color = .white, intensity: Double = 0.5) {
        self.color = color
        self.intensity = intensity
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(intensity),
                                color.opacity(intensity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 4)
                            .erased
                    )
            )
    }
}

public extension View {
    func innerGlow(color: Color = .white, intensity: Double = 0.5) -> some View {
        modifier(InnerGlow(color: color, intensity: intensity))
    }
}

// MARK: - Noise Texture Modifier

public struct NoiseTexture: View {
    private let opacity: Double
    
    public init(opacity: Double = 0.03) {
        self.opacity = opacity
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Placeholder for noise texture
                // In production, use an actual noise image
                Rectangle()
                    .fill(Color.clear)
                    .overlay(
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(opacity)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: max(geometry.size.width, geometry.size.height) / 2
                                )
                            )
                            .blendMode(.overlay)
                    )
                    .blendMode(.multiply)
            }
        }
    }
}

public extension View {
    func noiseTexture(opacity: Double = 0.03) -> some View {
        overlay(NoiseTexture(opacity: opacity))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        Text("Glass Effects Demo")
            .font(.title)
            .padding()
        
        // Basic Glass
        Text("Basic Glass")
            .padding()
            .glass()
        
        // Glass with custom radius
        Text("Custom Radius")
            .padding()
            .glass(cornerRadius: 24)
        
        // Glass with glow
        Text("Glow Effect")
            .padding()
            .glass(shadow: .glow)
        
        // Glass with strong shadow
        Text("Strong Shadow")
            .padding()
            .glass(shadow: .strong)
        
        // Using modifier
        Text("Glass Effect Modifier")
            .padding()
            .glassEffect(
                opacity: 0.4,
                blurRadius: 20,
                cornerRadius: 12
            )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .environmentObject(ThemeManager.shared)
}
