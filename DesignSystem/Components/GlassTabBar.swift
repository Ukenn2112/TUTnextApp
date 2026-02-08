import SwiftUI

// MARK: - Glass Tab Bar

public struct GlassTabBar<Tab: Identifiable>: View where Tab.ID == Int {
    @Binding private var selectedTab: Tab
    private let tabs: [Tab]
    private let tabItem: (Tab, Bool) -> AnyView
    private let backgroundOpacity: Double
    private let cornerRadius: CGFloat
    private let showLabels: Bool
    
    public init(
        selectedTab: Binding<Tab>,
        tabs: [Tab],
        @ViewBuilder tabItem: @escaping (Tab, Bool) -> AnyView,
        backgroundOpacity: Double = 0.85,
        cornerRadius: CGFloat = 24,
        showLabels: Bool = true
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.tabItem = tabItem
        self.backgroundOpacity = backgroundOpacity
        self.cornerRadius = cornerRadius
        self.showLabels = showLabels
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab.id == tab.id,
                    showLabel: showLabels,
                    tabItem: tabItem
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    GestureAnimations.lightImpact.impactOccurred()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            GlassTabBarBackground(
                opacity: backgroundOpacity,
                cornerRadius: cornerRadius
            )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Glass Tab Bar Background

struct GlassTabBarBackground: View {
    private let opacity: Double
    private let cornerRadius: CGFloat
    
    init(opacity: Double, cornerRadius: CGFloat) {
        self.opacity = opacity
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .light)
            .blur(radius: 20)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(opacity),
                                Color.white.opacity(opacity * 0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
    }
}

// MARK: - Tab Bar Item

struct TabBarItem<Tab: Identifiable>: View {
    private let tab: Tab
    private let isSelected: Bool
    private let showLabel: Bool
    private let tabItem: (Tab, Bool) -> AnyView
    
    init(
        tab: Tab,
        isSelected: Bool,
        showLabel: Bool,
        tabItem: @escaping (Tab, Bool) -> AnyView
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.showLabel = showLabel
        self.tabItem = tabItem
    }
    
    var body: some View {
        tabItem(tab, isSelected)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Glass Tab Item View

public struct GlassTabItem: View {
    private let icon: String
    private let label: String
    private let isSelected: Bool
    private let badge: Int?
    
    public init(
        icon: String,
        label: String,
        isSelected: Bool,
        badge: Int? = nil
    ) {
        self.icon = icon
        self.label = label
        self.isSelected = isSelected
        self.badge = badge
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? ThemeColors.Glass.medium : Color.clear)
                    )
                
                if let badge = badge, badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 8, y: -4)
                }
            }
            
            if isSelected {
                Text(label)
                    .font(Typography.labelSmall)
                    .foregroundStyle(.primary)
            } else {
                Text(label)
                    .font(Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Glass Tab Bar with Enum

public struct GlassTabBarEnum<Tab: RawRepresentable>: View where Tab.RawValue == Int, Tab: CaseIterable {
    @Binding private var selectedTab: Tab
    private let tabs: [Tab]
    private let icons: [Tab: String]
    private let labels: [Tab: String]
    private let backgroundOpacity: Double
    private let cornerRadius: CGFloat
    
    public init(
        selectedTab: Binding<Tab>,
        icons: [Tab: String],
        labels: [Tab: String],
        backgroundOpacity: Double = 0.85,
        cornerRadius: CGFloat = 24
    ) {
        self._selectedTab = selectedTab
        self.tabs = Tab.allCases
        self.icons = icons
        self.labels = labels
        self.backgroundOpacity = backgroundOpacity
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                GlassTabItem(
                    icon: icons[tab] ?? "circle",
                    label: labels[tab] ?? "",
                    isSelected: selectedTab == tab
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    GestureAnimations.lightImpact.impactOccurred()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            GlassTabBarBackground(opacity: backgroundOpacity, cornerRadius: cornerRadius)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Floating Glass Tab Bar

public struct FloatingGlassTabBar<Tab: Identifiable>: View where Tab.ID == Int {
    @Binding private var selectedTab: Tab
    private let tabs: [Tab]
    private let tabItem: (Tab, Bool) -> AnyView
    private let onTap: ((Tab) -> Void)?
    
    public init(
        selectedTab: Binding<Tab>,
        tabs: [Tab],
        @ViewBuilder tabItem: @escaping (Tab, Bool) -> AnyView,
        onTap: ((Tab) -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.tabItem = tabItem
        self.onTap = onTap
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                tabItem(tab, selectedTab.id == tab.id)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                        GestureAnimations.lightImpact.impactOccurred()
                        onTap?(tab)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .blur(radius: 15)
                .overlay(
                    Capsule()
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
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview {
    struct TabItem: Identifiable {
        let id: Int
        let icon: String
        let label: String
    }
    
    struct PreviewWrapper: View {
        @State private var selectedTab = TabItem(id: 0, icon: "house.fill", label: "Home")
        
        private let tabs = [
            TabItem(id: 0, icon: "house.fill", label: "Home"),
            TabItem(id: 1, icon: "magnifyingglass", label: "Search"),
            TabItem(id: 2, icon: "plus.circle.fill", label: "Create"),
            TabItem(id: 3, icon: "heart.fill", label: "Saved"),
            TabItem(id: 4, icon: "person.fill", label: "Profile")
        ]
        
        var body: some View {
            ZStack {
                Color.clear
                
                VStack {
                    Spacer()
                    
                    // Content
                    Text("Selected Tab: \(tabs[selectedTab.id].label)")
                        .font(.title)
                        .padding()
                }
                
                // Tab Bar at bottom
                VStack {
                    Spacer()
                    
                    GlassTabBar(
                        selectedTab: $selectedTab,
                        tabs: tabs
                    ) { tab, isSelected in
                        AnyView(
                            GlassTabItem(
                                icon: tab.icon,
                                label: tab.label,
                                isSelected: isSelected,
                                badge: tab.id == 3 ? 5 : nil
                            )
                        )
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
