import SwiftUI

// MARK: - Typography System

public enum Typography {
    
    // MARK: - Font Styles
    
    /// Large headline for major sections
    public static let headlineLarge = Font.system(size: 34, weight: .bold, design: .default)
    /// Medium headline for subsections
    public static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .default)
    /// Small headline for minor headings
    public static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    /// Large title for screens and modals
    public static let titleLarge = Font.system(size: 22, weight: .bold, design: .default)
    /// Medium title for sections
    public static let titleMedium = Font.system(size: 18, weight: .semibold, design: .default)
    /// Small title for cards and items
    public static let titleSmall = Font.system(size: 16, weight: .semibold, design: .default)
    
    /// Large body text for reading content
    public static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    /// Medium body text for standard content
    public static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    /// Small body text for dense content
    public static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    
    /// Large callout text
    public static let callout = Font.system(size: 16, weight: .medium, design: .default)
    
    /// Large caption for emphasis
    public static let captionLarge = Font.system(size: 14, weight: .medium, design: .default)
    /// Small caption for secondary information
    public static let caption = Font.system(size: 12, weight: .regular, design: .default)
    /// Ultra small caption for fine print
    public static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)
    
    /// Footnote text
    public static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    
    /// Large label for buttons
    public static let labelLarge = Font.system(size: 16, weight: .semibold, design: .default)
    /// Medium label for UI elements
    public static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)
    /// Small label for tags and badges
    public static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)
    
    // MARK: - Monospace Fonts
    
    public static let monospacedHeadline = Font.system(size: 28, weight: .bold, design: .monospaced)
    public static let monospacedBody = Font.system(size: 16, weight: .regular, design: .monospaced)
    public static let monospacedCaption = Font.system(size: 12, weight: .regular, design: .monospaced)
    
    // MARK: - Rounded Fonts
    
    public static let roundedHeadline = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let roundedBody = Font.system(size: 16, weight: .medium, design: .rounded)
    
    // MARK: - Serif Fonts
    
    public static let serifHeadline = Font.system(size: 34, weight: .bold, design: .serif)
    public static let serifBody = Font.system(size: 18, weight: .regular, design: .serif)
}

// MARK: - Typography Style

public enum TypographyStyle {
    case headlineLarge
    case headlineMedium
    case headlineSmall
    case titleLarge
    case titleMedium
    case titleSmall
    case bodyLarge
    case bodyMedium
    case bodySmall
    case captionLarge
    case caption
    case captionSmall
    case labelLarge
    case labelMedium
    case labelSmall
    case footnote
    
    var font: Font {
        switch self {
        case .headlineLarge: return Typography.headlineLarge
        case .headlineMedium: return Typography.headlineMedium
        case .headlineSmall: return Typography.headlineSmall
        case .titleLarge: return Typography.titleLarge
        case .titleMedium: return Typography.titleMedium
        case .titleSmall: return Typography.titleSmall
        case .bodyLarge: return Typography.bodyLarge
        case .bodyMedium: return Typography.bodyMedium
        case .bodySmall: return Typography.bodySmall
        case .captionLarge: return Typography.captionLarge
        case .caption: return Typography.caption
        case .captionSmall: return Typography.captionSmall
        case .labelLarge: return Typography.labelLarge
        case .labelMedium: return Typography.labelMedium
        case .labelSmall: return Typography.labelSmall
        case .footnote: return Typography.footnote
        }
    }
}

// MARK: - View Extension

public extension View {
    func typography(_ style: TypographyStyle) -> some View {
        self.font(style.font)
    }
    
    func typography(_ style: TypographyStyle, color: Color) -> some View {
        self.font(style.font).foregroundStyle(color)
    }
}

// MARK: - Text Styles with Customization

public struct StyledText: View {
    private let text: String
    private let style: TypographyStyle
    private let color: Color?
    private let opacity: Double
    
    public init(_ text: String, style: TypographyStyle, color: Color? = nil, opacity: Double = 1.0) {
        self.text = text
        self.style = style
        self.color = color
        self.opacity = opacity
    }
    
    public var body: some View {
        Text(text)
            .font(style.font)
            .foregroundStyle(color ?? .primary)
            .opacity(opacity)
    }
}

// MARK: - Responsive Typography Modifier

public struct ResponsiveTypography: ViewModifier {
    private let style: TypographyStyle
    
    public init(style: TypographyStyle) {
        self.style = style
    }
    
    public func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(lineSpacing(for: style))
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
    }
    
    private func lineSpacing(for style: TypographyStyle) -> CGFloat {
        switch style {
        case .headlineLarge, .headlineMedium, .headlineSmall:
            return 4
        case .titleLarge, .titleMedium, .titleSmall:
            return 2
        case .bodyLarge, .bodyMedium, .bodySmall:
            return 6
        default:
            return 4
        }
    }
}

public extension View {
    func responsiveTypography(_ style: TypographyStyle) -> some View {
        modifier(ResponsiveTypography(style: style))
    }
}

// MARK: - Text Alignment Modifier

public struct AlignedText: ViewModifier {
    private let alignment: TextAlignment
    
    public init(alignment: TextAlignment) {
        self.alignment = alignment
    }
    
    public func body(content: Content) -> some View {
        content.multilineTextAlignment(alignment)
    }
}

public extension View {
    func alignedText(_ alignment: TextAlignment) -> some View {
        modifier(AlignedText(alignment: alignment))
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        StyledText("Headline Large", style: .headlineLarge)
        StyledText("Headline Medium", style: .headlineMedium)
        StyledText("Headline Small", style: .headlineSmall)
        StyledText("Title Large", style: .titleLarge)
        StyledText("Title Medium", style: .titleMedium)
        StyledText("Title Small", style: .titleSmall)
        StyledText("Body Large", style: .bodyLarge)
        StyledText("Body Medium", style: .bodyMedium)
        StyledText("Body Small", style: .bodySmall)
        StyledText("Caption Large", style: .captionLarge)
        StyledText("Caption", style: .caption)
        StyledText("Caption Small", style: .captionSmall)
        StyledText("Label Large", style: .labelLarge)
        StyledText("Label Medium", style: .labelMedium)
        StyledText("Label Small", style: .labelSmall)
        StyledText("Footnote", style: .footnote)
    }
    .padding()
}
