import SwiftUI

// MARK: - Glass Card

public struct GlassCard<Content: View>: View {
    private let content: Content
    private let variant: CardVariant
    private let cornerRadius: CGFloat
    private let padding: EdgeInsets
    
    public enum CardVariant {
        case elevated
        case bordered
        case outline
        case flat
        case interactive
    }
    
    public init(
        variant: CardVariant = .elevated,
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.variant = variant
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border, lineWidth: borderWidth)
            )
            .shadow(radius: shadowRadius, x: shadowX, y: shadowY)
    }
    
    private var background: some View {
        Group {
            switch variant {
            case .elevated:
                ThemeColors.Glass.medium
            case .bordered:
                ThemeColors.Glass.light
            case .outline:
                Color.clear
            case .flat:
                Color.clear
            case .interactive:
                ThemeColors.Glass.light
            }
        }
    }
    
    private var border: some View {
        Group {
            switch variant {
            case .elevated:
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .bordered:
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .outline:
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .flat:
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .interactive:
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var borderWidth: CGFloat {
        switch variant {
        case .elevated: return 1
        case .bordered: return 2
        case .outline: return 1
        case .flat: return 0
        case .interactive: return 1
        }
    }
    
    private var shadowRadius: CGFloat {
        switch variant {
        case .elevated: return 12
        case .bordered: return 8
        case .outline: return 0
        case .flat: return 0
        case .interactive: return 8
        }
    }
    
    private var shadowX: CGFloat {
        switch variant {
        case .elevated: return 0
        case .bordered: return 0
        case .outline: return 0
        case .flat: return 0
        case .interactive: return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch variant {
        case .elevated: return 6
        case .bordered: return 4
        case .outline: return 0
        case .flat: return 0
        case .interactive: return 4
        }
    }
}

// MARK: - Glass Card Variants

public struct GlassElevatedCard<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GlassCard(variant: .elevated, cornerRadius: 20) {
            content
        }
    }
}

public struct GlassBorderedCard<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GlassCard(variant: .bordered, cornerRadius: 16) {
            content
        }
    }
}

public struct GlassOutlineCard<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GlassCard(variant: .outline, cornerRadius: 12) {
            content
        }
    }
}

// MARK: - Interactive Glass Card

public struct InteractiveGlassCard<Content: View>: View {
    private let content: Content
    private let action: () -> Void
    
    @State private var isPressed = false
    
    public init(
        @ViewBuilder content: () -> Content,
        action: @escaping () -> Void
    ) {
        self.content = content()
        self.action = action
    }
    
    public var body: some View {
        GlassCard(variant: .interactive, cornerRadius: 16) {
            content
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .brightness(isPressed ? 0.02 : 0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            GestureAnimations.lightImpact.impactOccurred()
            action()
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Glass Card with Header

public struct GlassCardWithHeader<Header: View, Content: View>: View {
    private let header: Header
    private let content: Content
    private let cornerRadius: CGFloat
    
    public init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Content
            content
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Glass Card Grid

public struct GlassCardGrid<Content: View>: View {
    private let columns: [GridItem]
    private let spacing: CGFloat
    private let content: Content
    
    public init(
        columns: [GridItem] = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ],
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Elevated Card
            GlassCard(variant: .elevated) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elevated Card")
                        .font(.headline)
                    Text("This is an elevated glass card with a soft shadow effect.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Bordered Card
            GlassCard(variant: .bordered) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bordered Card")
                        .font(.headline)
                    Text("This is a bordered glass card with a prominent border.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Outline Card
            GlassCard(variant: .outline) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outline Card")
                        .font(.headline)
                    Text("This is an outline glass card without background.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Interactive Card
            InteractiveGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interactive Card")
                        .font(.headline)
                    Text("Tap or long press this card for feedback.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } action: {
                print("Card tapped!")
            }
            
            // Card with Header
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Featured")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                }
            } content: {
                Text("This card has a header section with custom content.")
                    .foregroundStyle(.secondary)
            }
            
            // Grid Layout
            GlassCardGrid {
                ForEach(0..<4, id: \.self) { index in
                    GlassCard(variant: .bordered) {
                        VStack {
                            Image(systemName: "star.fill")
                                .font(.largeTitle)
                            Text("Item \(index + 1)")
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
