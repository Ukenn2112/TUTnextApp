import SwiftUI

// MARK: - Glass Button

public struct GlassButton: View {
    private let title: String
    private let variant: ButtonVariant
    private let isEnabled: Bool
    private let action: () -> Void
    
    public enum ButtonVariant {
        case primary
        case secondary
        case ghost
        case danger
        case success
    }
    
    public init(
        _ title: String,
        variant: ButtonVariant = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            GestureAnimations.lightImpact.impactOccurred()
            action()
        }) {
            Text(title)
                .font(Typography.labelLarge)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(radius: shadowRadius)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .pressEffect()
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .ghost:
            return .primary
        case .danger:
            return .white
        case .success:
            return .white
        }
    }
    
    private var background: some View {
        Group {
            switch variant {
            case .primary:
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .secondary:
                ThemeColors.Glass.medium
            case .ghost:
                Color.clear
            case .danger:
                LinearGradient(
                    colors: [Color.red.opacity(0.9), Color.red.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .success:
                LinearGradient(
                    colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary:
            return Color.white.opacity(0.3)
        case .secondary:
            return Color.white.opacity(0.4)
        case .ghost:
            return Color.white.opacity(0.3)
        case .danger:
            return Color.white.opacity(0.3)
        case .success:
            return Color.white.opacity(0.3)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch variant {
        case .primary, .danger, .success:
            return 8
        default:
            return 0
        }
    }
}

// MARK: - Glass Icon Button

public struct GlassIconButton: View {
    private let icon: String
    private let action: () -> Void
    private let size: CGFloat
    private let iconSize: CGFloat
    
    public init(
        icon: String,
        size: CGFloat = 48,
        iconSize: CGFloat = 24,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            GestureAnimations.lightImpact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(ThemeColors.Glass.medium)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .pressEffect()
    }
}

// MARK: - Glass Toggle Button

public struct GlassToggleButton: View {
    @Binding private var isOn: Bool
    private let onIcon: String
    private let offIcon: String
    private let action: () -> Void
    
    public init(
        isOn: Binding<Bool>,
        onIcon: String = "checkmark.circle.fill",
        offIcon: String = "circle",
        action: @escaping () -> Void
    ) {
        self._isOn = isOn
        self.onIcon = onIcon
        self.offIcon = offIcon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            GestureAnimations.lightImpact.impactOccurred()
            isOn.toggle()
            action()
        }) {
            HStack {
                Image(systemName: isOn ? onIcon : offIcon)
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.green : .secondary)
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.Glass.light)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Glass Loading Button

public struct GlassLoadingButton: View {
    private let title: String
    @Binding private var isLoading: Bool
    private let action: () -> Void
    
    public init(
        _ title: String,
        isLoading: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        self.title = title
        self._isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            guard !isLoading else { return }
            GestureAnimations.lightImpact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isLoading ? "Loading..." : title)
                    .font(Typography.labelLarge)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        GlassButton("Primary Button", variant: .primary) {
            print("Primary tapped")
        }
        
        GlassButton("Secondary Button", variant: .secondary) {
            print("Secondary tapped")
        }
        
        GlassButton("Ghost Button", variant: .ghost) {
            print("Ghost tapped")
        }
        
        GlassButton("Danger Button", variant: .danger) {
            print("Danger tapped")
        }
        
        GlassButton("Success Button", variant: .success) {
            print("Success tapped")
        }
        
        HStack {
            GlassIconButton(icon: "heart.fill") {
                print("Heart tapped")
            }
            
            GlassIconButton(icon: "star.fill") {
                print("Star tapped")
            }
            
            GlassIconButton(icon: "bell.fill") {
                print("Bell tapped")
            }
        }
        
        GlassLoadingButton(
            "Submit",
            isLoading: .constant(false)
        ) {
            print("Submit tapped")
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
