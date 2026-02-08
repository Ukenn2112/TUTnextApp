# TUTnext Design System

A comprehensive Glassmorphism UI Kit for iOS built with SwiftUI, featuring iOS 17+ support, spring animations, and a complete theming system.

## Features

### 🎨 Design System Components

#### Colors (`DesignSystem/Colors/`)
- **ThemeColors**: Complete color palette with glass colors, gradients, and semantic colors
- **ThemeManager**: Light/Dark theme support with multiple theme options (Light, Dark, Midnight, Blush, Forest)
- **ColorExtensions**: Utility extensions for working with colors, hex values, and gradients

#### Typography (`DesignSystem/Typography/`)
- **Typography**: Complete typography scale with headline, title, body, caption, and label styles
- **ResponsiveTypography**: Adaptive typography that scales appropriately
- **StyledText**: Convenience wrapper for styled text components

#### Effects (`DesignSystem/Effects/`)
- **GlassEffects**: Core glassmorphism effects using iOS 17+ `MaterialBlurView`
- **GlassView**: Convenient view modifier for applying glass effects
- **Shadow utilities**: Pre-configured shadow styles for different elevations
- **InnerGlow**: Inner glow effect for interactive elements
- **NoiseTexture**: Subtle noise texture for depth

#### Animations (`DesignSystem/Animations/`)
- **SpringAnimations**: Pre-configured spring animations (smooth, snappy, bouncy, elegant)
- **Transition modifiers**: Glass-specific transitions (fade, pop, sheet, modal)
- **Gesture animations**: Scale, press, drag, and shake effects
- **iOS 17+ spring API**: Uses the new `Animation.spring(duration:bounce:)` API

#### Components (`DesignSystem/Components/`)

##### GlassButton
Multiple button variants:
- **Primary**: Gradient background with accent color
- **Secondary**: Glass background with subtle border
- **Ghost**: Transparent background with border
- **Danger/Success**: Semantic color variants
- Additional variants: IconButton, ToggleButton, LoadingButton

##### GlassCard
Card components with multiple variants:
- **Elevated**: Medium glass with soft shadow
- **Bordered**: Light glass with prominent border
- **Outline**: Transparent with gradient border
- **Interactive**: Pressable cards with feedback
- **GlassCardWithHeader**: Cards with header sections
- **GlassCardGrid**: Grid layout for card collections

##### GlassModal
Modal presentations:
- **GlassModal**: Sheet presentations with blur material
- **GlassAlert**: Alert dialogs with glass styling
- **GlassConfirmationDialog**: Confirmation actions
- **GlassPopover**: Popover presentations
- **GlassFullScreenCover**: Full-screen covers

##### Toast (`Toast.swift`)
Toast notification system:
- **ToastManager**: Global toast management
- **ToastView**: Individual toast component
- **GlassToast**: Glass-styled toast notifications
- Four types: Success, Warning, Error, Info

##### GlassNavigationBar
Navigation components:
- **GlassNavigationBar**: Customizable navigation bar
- **GlassNavigationView**: NavigationStack wrapper
- **GlassNavigationTitle**: Title with optional subtitle
- **GlassSearchBar**: Search input with glass styling
- **GlassNavigationButton**: Icon buttons for navigation

##### GlassTabBar
Tab bar components:
- **GlassTabBar**: Custom glass tab bar
- **GlassTabItem**: Individual tab items with badges
- **GlassTabBarEnum**: Type-safe enum-based tab bar
- **FloatingGlassTabBar**: Floating capsule-style tab bar

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/your-org/TUTnextDesignSystem.git", from: "1.0.0")
]
```

### Manual Installation

1. Copy the `DesignSystem` folder to your project
2. Import the module where needed:
```swift
import TUTnextDesignSystem
```

## Usage

### Basic Setup

```swift
import SwiftUI
import TUTnextDesignSystem

@main
struct MyApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
```

### Using Glass Components

```swift
// Glass Button
GlassButton("Primary", variant: .primary) {
    print("Tapped!")
}

// Glass Card
GlassCard(variant: .elevated) {
    Text("Card Content")
}

// Glass View
Text("Hello")
    .glass(opacity: 0.4, cornerRadius: 16)
```

### Theming

```swift
// Switch theme
ThemeManager.shared.setTheme(.dark)

// Toggle system theme
ThemeManager.shared.useSystemThemeSetting()

// Cycle through themes
ThemeManager.shared.cycleTheme()
```

### Animations

```swift
// Apply spring animation
Text("Animate me")
    .springAnimate(.bouncy)

// Gesture effects
Button("Tap me") { }
    .scaleOnTap()
    .pressEffect()

// Transitions
SomeView()
    .modalTransition()
```

## Theme Options

| Theme | Color Scheme | Use Case |
|-------|-------------|----------|
| Light | Light | Daytime, content-focused |
| Dark | Dark | Nighttime, media-focused |
| Midnight | Dark | OLED screens, immersive |
| Blush | Light | Soft, feminine designs |
| Forest | Light | Nature-themed apps |

## iOS Compatibility

- **Minimum iOS Version**: iOS 16.0
- **Recommended iOS Version**: iOS 17.0+
- **Features requiring iOS 17+**:
  - `UIBlurEffect.Style.systemMaterial` improvements
  - New `Animation.spring(duration:bounce:)` API
  - Advanced material effects

## Customization

### Extending Colors

```swift
extension ThemeColors {
    public enum Custom {
        public static let brandPrimary = Color(hex: "#FF6B35")
        public static let brandSecondary = Color(hex: "#004E89")
    }
}
```

### Creating Custom Components

```swift
public struct MyCustomGlassComponent: View {
    public init() {}
    
    public var body: some View {
        Text("Custom")
            .glass()
    }
}
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your changes
4. Submit a pull request

## Credits

Built with ❤️ for the TUTnext project.
