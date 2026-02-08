import SwiftUI

// MARK: - Spring Animations

public enum SpringAnimations {
    
    // MARK: - Preset Spring Animations
    
    /// Smooth spring animation with medium tension and damping
    public static let smooth = Animation.spring(
        response: 0.5,
        dampingFraction: 0.7,
        blendDuration: 0.3
    )
    
    /// Snappy spring animation for quick interactions
    public static let snappy = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.2
    )
    
    /// Bouncy spring animation for playful elements
    public static let bouncy = Animation.spring(
        response: 0.6,
        dampingFraction: 0.5,
        blendDuration: 0.3
    )
    
    /// Slow spring animation for elegant transitions
    public static let elegant = Animation.spring(
        response: 0.7,
        dampingFraction: 0.8,
        blendDuration: 0.5
    )
    
    /// Quick spring for micro-interactions
    public static let quick = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7,
        blendDuration: 0.15
    )
    
    /// Heavy spring for large elements
    public static let heavy = Animation.spring(
        response: 0.8,
        dampingFraction: 0.7,
        blendDuration: 0.5
    )
    
    // MARK: - iOS 17+ Spring Animation
    
    /// Using iOS 17's new spring animation API
    public static func spring(
        duration: Double = 0.5,
        bounce: Double = 0.0
    ) -> Animation {
        if #available(iOS 17.0, *) {
            return .spring(
                duration: duration,
                bounce: bounce
            )
        } else {
            return smooth
        }
    }
    
    /// Interpolating spring for complex animations
    @available(iOS 17.0, *)
    public static let interpolatingSpring = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 170,
        damping: 16
    )
}

// MARK: - Animation Modifier

public struct SpringAnimation: ViewModifier {
    private let animation: Animation
    private let isEnabled: Bool
    
    public init(_ animation: Animation, isEnabled: Bool = true) {
        self.animation = animation
        self.isEnabled = isEnabled
    }
    
    public func body(content: Content) -> some View {
        content.animation(isEnabled ? animation : nil, value: UUID())
    }
}

public extension View {
    func springAnimate(_ animation: Animation = SpringAnimations.smooth, isEnabled: Bool = true) -> some View {
        modifier(SpringAnimation(animation, isEnabled: isEnabled))
    }
}

// MARK: - Transition Modifiers

public enum GlassTransitions {
    
    // MARK: - Slide Transitions
    
    public static let slide = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    public static let slideUp = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )
    
    public static let slideDown = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
    
    // MARK: - Scale Transitions
    
    public static let scale = AnyTransition.scale
        .combined(with: .opacity)
    
    public static let scaleAndSlide = AnyTransition.asymmetric(
        insertion: .scale.combined(with: .offset(x: 50)).combined(with: .opacity),
        removal: .scale.combined(with: .offset(x: -50)).combined(with: .opacity)
    )
    
    // MARK: - Glass-specific Transitions
    
    public static let glassFade = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeIn(duration: 0.3)),
        removal: .opacity.animation(.easeOut(duration: 0.2))
    )
    
    public static let glassPop = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.9)
            .combined(with: .opacity)
            .animation(SpringAnimations.bouncy),
        removal: .scale(scale: 0.95)
            .combined(with: .opacity)
            .animation(SpringAnimations.quick)
    )
    
    public static let glassSheet = AnyTransition.asymmetric(
        insertion: .offset(y: UIScreen.main.bounds.height)
            .combined(with: .opacity),
        removal: .offset(y: UIScreen.main.bounds.height)
            .combined(with: .opacity)
    )
    
    public static let glassModal = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.8)
            .combined(with: .opacity),
        removal: .scale(scale: 0.8)
            .combined(with: .opacity)
    )
    
    // MARK: - iOS 17+ Transitions
    
    @available(iOS 17.0, *)
    public static var materialFade: AnyTransition {
        .blurReplace
    }
}

// MARK: - Transition Extension

public extension View {
    func glassTransition(_ type: GlassTransitions.Type = GlassTransitions.self) -> some View {
        self.transition(GlassTransitions.glassFade)
    }
    
    func sheetTransition() -> some View {
        self.transition(GlassTransitions.glassSheet)
    }
    
    func modalTransition() -> some View {
        self.transition(GlassTransitions.glassModal)
    }
}

// MARK: - Gesture Animations

public struct GestureAnimations {
    
    /// Scale animation for tap feedback
    public static let tap = Animation.spring(
        response: 0.3,
        dampingFraction: 0.6
    )
    
    /// Scale animation for long press
    public static let press = Animation.easeInOut(duration: 0.15)
    
    /// Scale animation for drag
    public static let drag = Animation.spring(
        response: 0.25,
        dampingFraction: 0.8
    )
    
    /// Rotation animation for swipe
    public static let rotation = Animation.spring(
        response: 0.4,
        dampingFraction: 0.7
    )
    
    /// Haptic feedback generator
    public static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    public static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    public static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    public static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    public static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    
    /// Selection feedback
    public static let selectionFeedback = UISelectionFeedbackGenerator()
}

// MARK: - Gesture Modifier

public struct ScaleOnTap: ViewModifier {
    @State private var isScaled = false
    private let scale: CGFloat
    private let animation: Animation
    
    public init(scale: CGFloat = 0.95, animation: Animation = GestureAnimations.tap) {
        self.scale = scale
        self.animation = animation
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(isScaled ? scale : 1.0)
            .animation(animation, value: isScaled)
            .onTapGesture {
                isScaled = true
                GestureAnimations.lightImpact.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isScaled = false
                }
            }
    }
}

public struct PressEffect: ViewModifier {
    @State private var isPressed = false
    private let scale: CGFloat
    private let brightness: Double
    
    public init(scale: CGFloat = 0.92, brightness: Double = 0.05) {
        self.scale = scale
        self.brightness = brightness
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .brightness(isPressed ? brightness : 0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

public struct DragEffect: ViewModifier {
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    private let onDragStart: (() -> Void)?
    private let onDragEnd: (() -> Void)?
    private let onDrag: ((CGSize) -> Void)?
    
    public init(
        onDragStart: (() -> Void)? = nil,
        onDragEnd: (() -> Void)? = nil,
        onDrag: ((CGSize) -> Void)? = nil
    ) {
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        self.onDrag = onDrag
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart?()
                            GestureAnimations.lightImpact.impactOccurred()
                        }
                        offset = value.translation
                        onDrag?(value.translation)
                    }
                    .onEnded { _ in
                        withAnimation(GestureAnimations.drag) {
                            offset = .zero
                        }
                        isDragging = false
                        onDragEnd?()
                    }
            )
    }
}

public extension View {
    func scaleOnTap(scale: CGFloat = 0.95) -> some View {
        modifier(ScaleOnTap(scale: scale))
    }
    
    func pressEffect(scale: CGFloat = 0.92) -> some View {
        modifier(PressEffect(scale: scale))
    }
    
    func dragEffect(
        onDragStart: (() -> Void)? = nil,
        onDragEnd: (() -> Void)? = nil,
        onDrag: ((CGSize) -> Void)? = nil
    ) -> some View {
        modifier(DragEffect(onDragStart: onDragStart, onDragEnd: onDragEnd, onDrag: onDrag))
    }
}

// MARK: - Animated Value

@propertyWrapper
public struct AnimatedValue<Value: Equatable>: DynamicProperty {
    @State private var value: Value
    
    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            withAnimation(SpringAnimations.smooth) {
                value = newValue
            }
        }
    }
    
    public init(wrappedValue: Value) {
        self._value = State(wrappedValue: wrappedValue)
    }
    
    public var projectedValue: Binding<Value> {
        Binding(
            get: { value },
            set: { newValue in
                withAnimation(SpringAnimations.smooth) {
                    value = newValue
                }
            }
        )
    }
}

// MARK: - Shake Animation

public struct ShakeEffect: GeometryEffect {
    private var shake: CGFloat
    private let shakeAmount: CGFloat
    
    public var animatableData: CGFloat {
        get { shake }
        set { shake = newValue }
    }
    
    public init(shake: CGFloat = 0, shakeAmount: CGFloat = 10) {
        self.shake = shake
        self.shakeAmount = shakeAmount
    }
    
    public func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(shake * .pi * 2) * shakeAmount
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

public extension View {
    func shake(trigger: Bool, shakeAmount: CGFloat = 10) -> some View {
        self.modifier(ShakeModifier(trigger: trigger, shakeAmount: shakeAmount))
    }
}

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    let shakeAmount: CGFloat
    
    @State private var shakeValue: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(shake: shakeValue, shakeAmount: shakeAmount))
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                withAnimation(.linear(duration: 0.4)) {
                    shakeValue = 4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeValue = 0
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Spring Animation
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.accentColor)
            .frame(width: 100, height: 100)
            .springAnimate(SpringAnimations.bouncy)
        
        // Scale on tap
        Text("Tap Me")
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleOnTap()
        
        // Press effect
        Text("Long Press")
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .pressEffect()
    }
    .padding()
}
