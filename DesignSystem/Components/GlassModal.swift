import SwiftUI

// MARK: - Glass Modal

public struct GlassModal<Content: View>: View {
    private let content: Content
    private let isPresented: Binding<Bool>
    private let detents: [PresentationDetent]
    private let prefersGrabberVisible: Bool
    private let cornerRadius: CGFloat
    
    public init(
        isPresented: Binding<Bool>,
        detents: [PresentationDetent] = [.medium, .large],
        prefersGrabberVisible: Bool = true,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isPresented = isPresented
        self.detents = detents
        self.prefersGrabberVisible = prefersGrabberVisible
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        GlassModalSheet(
            isPresented: isPresented,
            detents: detents,
            prefersGrabberVisible: prefersGrabberVisible,
            cornerRadius: cornerRadius
        ) {
            content
        }
    }
}

// MARK: - Glass Modal Sheet

struct GlassModalSheet<Content: View>: View {
    private let content: Content
    private let isPresented: Binding<Bool>
    private let detents: [PresentationDetent]
    private let prefersGrabberVisible: Bool
    private let cornerRadius: CGFloat
    
    init(
        isPresented: Binding<Bool>,
        detents: [PresentationDetent],
        prefersGrabberVisible: Bool,
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isPresented = isPresented
        self.detents = detents
        self.prefersGrabberVisible = prefersGrabberVisible
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents(detents)
                .presentationDragIndicator(prefersGrabberVisible)
                .presentationCornerRadius(cornerRadius)
                .modifier(GlassSheetModifier(cornerRadius: cornerRadius))
        } else {
            content
                .modifier(GlassSheetModifier(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Glass Sheet Modifier

struct GlassSheetModifier: ViewModifier {
    private let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
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
        } else {
            content
                .background(
                    ThemeColors.Glass.medium
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Glass Alert

public struct GlassAlert: View {
    private let title: String
    private let message: String
    private let primaryButtonTitle: String
    private let secondaryButtonTitle: String?
    private let primaryAction: () -> Void
    private let secondaryAction: (() -> Void)?
    private let isPresented: Binding<Bool>
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        isPresented: Binding<Bool>,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            // Message
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Buttons
            VStack(spacing: 12) {
                if let secondaryButtonTitle = secondaryButtonTitle, let secondaryAction = secondaryAction {
                    GlassButton(secondaryButtonTitle, variant: .ghost) {
                        secondaryAction()
                        isPresented.wrappedValue = false
                    }
                }
                
                GlassButton(primaryButtonTitle, variant: .primary) {
                    primaryAction()
                    isPresented.wrappedValue = false
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
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
        .padding(20)
    }
}

// MARK: - Glass Confirmation Dialog

public struct GlassConfirmationDialog<Content: View>: View {
    private let title: String
    private let content: Content
    private let actions: [ActionButton]
    
    struct ActionButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void
    }
    
    public init(
        title: String,
        @ViewBuilder content: () -> Content,
        @ActionBuilder actions: () -> [ActionButton]
    ) {
        self.title = title
        self.content = content()
        self.actions = actions()
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(title)
                .font(.headline)
                .padding(.top, 8)
            
            // Content
            content
            
            // Actions
            VStack(spacing: 8) {
                ForEach(actions, id: \.title) { action in
                    GlassButton(action.title, variant: action.role == .destructive ? .danger : .primary) {
                        action.action()
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(16)
    }
}

extension GlassConfirmationDialog {
    @ResultBuilder
    public static func actionBuilder(@ArrayBuilder<ActionButton> components: () -> [ActionButton]) -> [ActionButton] {
        components()
    }
}

// MARK: - Glass Popover

public struct GlassPopover<Content: View>: View {
    private let content: Content
    private let arrowEdge: Edge
    private let cornerRadius: CGFloat
    
    public init(
        arrowEdge: Edge = .top,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.arrowEdge = arrowEdge
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemeColors.Glass.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Glass Full Screen Cover

public struct GlassFullScreenCover<Content: View>: View {
    private let content: Content
    private let isPresented: Binding<Bool>
    
    public init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.isPresented = isPresented
    }
    
    public var body: some View {
        content
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
            )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var showModal = false
        @State private var showAlert = false
        
        var body: some View {
            VStack(spacing: 20) {
                GlassButton("Show Modal") {
                    showModal = true
                }
                
                GlassButton("Show Alert") {
                    showAlert = true
                }
            }
            .sheet(isPresented: $showModal) {
                GlassModal(isPresented: $showModal) {
                    VStack(spacing: 20) {
                        Text("Glass Modal")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("This is a glassmorphic modal sheet presentation.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        GlassButton("Close", variant: .ghost) {
                            showModal = false
                        }
                    }
                    .padding(24)
                }
            }
            .overlay {
                if showAlert {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showAlert = false
                            }
                        
                        GlassAlert(
                            title: "Confirm Action",
                            message: "Are you sure you want to proceed with this action?",
                            primaryButtonTitle: "Confirm",
                            secondaryButtonTitle: "Cancel",
                            isPresented: $showAlert
                        ) {
                            print("Confirmed!")
                        } secondaryAction: {
                            print("Cancelled!")
                        }
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
}
