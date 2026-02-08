import SwiftUI

// MARK: - View Extensions

extension View {
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Color Extensions

extension Color {
    static let primaryBackground = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let tertiaryText = Color(UIColor.tertiaryLabel)
    
    static let accent = Color.accentColor
    static let error = Color.red
    static let success = Color.green
    static let warning = Color.orange
}

// MARK: - Font Extensions

extension Font {
    static let titleLarge = Font(.system(size: 34, weight: .bold))
    static let titleMedium = Font(.system(size: 28, weight: .semibold))
    static let titleSmall = Font(.system(size: 22, weight: .semibold))
    
    static let headline = Font(.system(size: 17, weight: .semibold))
    static let body = Font(.system(size: 17, weight: .regular))
    static let callout = Font(.system(size: 16, weight: .regular))
    
    static let subheadline = Font(.system(size: 15, weight: .regular))
    static let footnote = Font(.system(size: 13, weight: .regular))
    static let caption = Font(.system(size: 12, weight: .regular))
    static let captionSmall = Font(.system(size: 11, weight: .regular))
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PlainButtonStyle {
    static var plain: PlainButtonStyle { PlainButtonStyle() }
}

extension ButtonStyle where Self == BorderedButtonStyle {
    static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}

// MARK: - Modal Extensions

extension View {
    func presentAsSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        self.sheet(isPresented: isPresented, content: content)
    }
    
    func presentAsAlert(title: String, message: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View) -> some View {
        self.alert(title, isPresented: isPresented) {
            actions()
        } message: {
            Text(message)
        }
    }
}

// MARK: - First Appear Modifier

struct FirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

// MARK: - Rounded Corner

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Builder Extensions

@resultBuilder
struct ConditionalContentBuilder<Content: View> {
    static func buildBlock(_ components: Content...) -> Content {
        if components.count == 1 {
            return components[0]
        } else {
            return VStack(spacing: 0)(components)
        }
    }
}

// MARK: - HStack/VStack with Multiple Views

extension HStack where Content == Never {
    init(@ViewBuilder _ content: () -> some View) {
        self = HStack(spacing: 0)(content())
    }
}

extension VStack where Content == Never {
    init(@ViewBuilder _ content: () -> some View) {
        self = VStack(spacing: 0)(content())
    }
}
