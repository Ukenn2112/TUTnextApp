import SwiftUI

// MARK: - Glass Navigation Bar

public struct GlassNavigationBar<Title: View, Leading: View, Trailing: View>: View {
    private let title: Title
    private let leading: Leading
    private let trailing: Trailing
    private let backgroundOpacity: Double
    private let blurRadius: CGFloat
    private let showBottomSeparator: Bool
    
    public init(
        backgroundOpacity: Double = 0.8,
        blurRadius: CGFloat = 20,
        showBottomSeparator: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title()
        self.leading = leading()
        self.trailing = trailing()
        self.backgroundOpacity = backgroundOpacity
        self.blurRadius = blurRadius
        self.showBottomSeparator = showBottomSeparator
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Leading items
            leading
                .frame(width: 44, height: 44)
            
            Spacer()
            
            // Title
            title
            
            Spacer()
            
            // Trailing items
            trailing
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Glass background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .blur(radius: blurRadius)
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(backgroundOpacity),
                        Color.white.opacity(backgroundOpacity * 0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            if showBottomSeparator {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Glass Navigation Bar Simple

public struct GlassNavigationBarSimple<Title: View>: View {
    private let title: Title
    private let backgroundOpacity: Double
    
    public init(
        backgroundOpacity: Double = 0.8,
        @ViewBuilder title: () -> Title
    ) {
        self.title = title()
        self.backgroundOpacity = backgroundOpacity
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .font(Typography.titleLarge)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .blur(radius: 20)
        )
    }
}

// MARK: - Glass Navigation View

public struct GlassNavigationView<Content: View>: View {
    private let content: Content
    private let navigationBar: AnyView?
    
    public init(
        @ViewBuilder content: () -> Content
    ) where Content: View {
        self.content = content()
        self.navigationBar = nil
    }
    
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder navigationBar: () -> some View
    ) where Content: View {
        self.content = content()
        self.navigationBar = AnyView(navigationBar())
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation bar overlay
                if let navigationBar = navigationBar {
                    VStack {
                        navigationBar
                        Spacer()
                    }
                    .pointerEvents(.none)
                }
            }
            .background(Color.clear)
        }
    }
}

// MARK: - Glass Navigation Title

public struct GlassNavigationTitle: View {
    private let title: String
    private let subtitle: String?
    
    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Glass Search Bar

public struct GlassSearchBar: View {
    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: (() -> Void)?
    
    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

// MARK: - Glass Navigation Button

public struct GlassNavigationButton: View {
    private let icon: String
    private let action: () -> Void
    
    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            GestureAnimations.lightImpact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(ThemeColors.Glass.light)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        
        var body: some View {
            GlassNavigationView {
                VStack {
                    GlassSearchBar(text: $searchText)
                        .padding()
                    
                    Spacer()
                }
            } navigationBar: {
                GlassNavigationBar(
                    backgroundOpacity: 0.85,
                    blurRadius: 25,
                    showBottomSeparator: true
                ) {
                    GlassNavigationTitle("TUTnext", subtitle: "Design System")
                } leading: {
                    GlassNavigationButton(icon: "line.3.horizontal") {
                        print("Menu tapped")
                    }
                } trailing: {
                    GlassNavigationButton(icon: "bell.fill") {
                        print("Notifications tapped")
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    return PreviewWrapper()
}
