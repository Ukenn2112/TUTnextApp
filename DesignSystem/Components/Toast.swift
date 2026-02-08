import SwiftUI

// MARK: - Toast Manager

@MainActor
public final class ToastManager: ObservableObject {
    public static let shared = ToastManager()
    
    @Published public var toasts: [Toast] = []
    
    private init() {}
    
    public func show(message: String, type: ToastType = .info, duration: Double = 3.0) {
        let toast = Toast(
            id: UUID(),
            message: message,
            type: type,
            duration: duration
        )
        
        toasts.append(toast)
        
        // Auto dismiss
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            dismiss(toast.id)
        }
    }
    
    public func dismiss(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            toasts.removeAll { $0.id == id }
        }
    }
    
    public func dismissAll() {
        toasts.removeAll()
    }
}

// MARK: - Toast Model

public struct Toast: Identifiable {
    public let id: UUID
    public let message: String
    public let type: ToastType
    public let duration: Double
    
    public init(
        id: UUID = UUID(),
        message: String,
        type: ToastType = .info,
        duration: Double = 3.0
    ) {
        self.id = id
        self.message = message
        self.type = type
        self.duration = duration
    }
}

// MARK: - Toast Type

public enum ToastType {
    case success
    case warning
    case error
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var colors: (background: Color, foreground: Color) {
        switch self {
        case .success:
            return (ThemeColors.Semantic.Toast.successBackground, ThemeColors.Semantic.Toast.successText)
        case .warning:
            return (ThemeColors.Semantic.Toast.warningBackground, ThemeColors.Semantic.Toast.warningText)
        case .error:
            return (ThemeColors.Semantic.Toast.errorBackground, ThemeColors.Semantic.Toast.errorText)
        case .info:
            return (ThemeColors.Semantic.Toast.infoBackground, ThemeColors.Semantic.Toast.infoText)
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    private let toast: Toast
    
    @State private var isAppearing = false
    
    init(toast: Toast) {
        self.toast = toast
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(toast.type.colors.foreground)
            
            // Message
            Text(toast.message)
                .font(Typography.bodyMedium)
                .foregroundStyle(toast.type.colors.foreground)
            
            Spacer()
            
            // Dismiss button
            Button(action: {
                ToastManager.shared.dismiss(toast.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(toast.type.colors.foreground.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.type.colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .frame(maxWidth: 350)
        .opacity(isAppearing ? 1.0 : 0.0)
        .offset(y: isAppearing ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Toast Container

struct ToastContainer: View {
    @StateObject private var toastManager = ToastManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    ForEach(toastManager.toasts) { toast in
                        ToastView(toast: toast)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
            }
            .pointerEvents(.none)
        }
    }
}

// MARK: - Glass Toast

public struct GlassToast: View {
    private let message: String
    private let type: ToastType
    private let onDismiss: (() -> Void)?
    
    public init(
        message: String,
        type: ToastType = .info,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.type = type
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(type.colors.foreground)
            
            Text(message)
                .font(Typography.bodyMedium)
                .foregroundStyle(type.colors.foreground)
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(type.colors.foreground.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Toast Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var toastManager = ToastManager.shared
        
        var body: some View {
            ZStack {
                Color.clear
                
                VStack(spacing: 16) {
                    GlassButton("Success Toast") {
                        toastManager.show(message: "Operation completed successfully!", type: .success)
                    }
                    
                    GlassButton("Error Toast") {
                        toastManager.show(message: "An error occurred. Please try again.", type: .error)
                    }
                    
                    GlassButton("Warning Toast") {
                        toastManager.show(message: "Warning: This action cannot be undone.", type: .warning)
                    }
                    
                    GlassButton("Info Toast") {
                        toastManager.show(message: "New updates are available.", type: .info)
                    }
                }
            }
            .overlay {
                ToastContainer()
            }
        }
    }
    
    return PreviewWrapper()
        .environmentObject(ToastManager.shared)
}
