//
//  ContentView.swift
//  TUTnext
//
//  Main Glassmorphism Content View with Navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var isLoggedIn = false
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var ratingService: RatingService
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
                    .transition(.opacity)
            } else {
                mainContentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isLoggedIn)
        .onAppear {
            checkLoginStatus()
            processInitialURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HandleURLScheme"))) { notification in
            if let url = notification.object as? URL {
                handleDeepLink(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToPageFromNotification"))) { notification in
            if let page = notification.userInfo?["page"] as? String {
                navigateBasedOnPath(page)
            }
        }
        .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
        .onChange(of: appearanceManager.isDarkMode) { _, newValue in
            print("ContentView detected isDarkMode change: \(newValue)")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppearanceDidChangeNotification"))) { _ in
            print("ContentView received appearance change notification")
        }
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            GlassHeaderView(selectedTab: $selectedTab, isLoggedIn: $isLoggedIn)
            
            // Tab Content
            TabView(selection: $selectedTab) {
                BusScheduleView()
                    .tag(0)
                    .environmentObject(themeManager)
                
                TimetableView(isLoggedIn: $isLoggedIn)
                    .tag(1)
                    .environmentObject(themeManager)
                
                AssignmentView(isLoggedIn: $isLoggedIn)
                    .tag(2)
                    .environmentObject(themeManager)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.bottom)
            
            // Tab Bar
            GlassTabBar(selectedTab: $selectedTab)
        }
    }
    
    // MARK: - Login Status Check
    private func checkLoginStatus() {
        let user = UserService.shared.getCurrentUser()
        isLoggedIn = user != nil
    }
    
    // MARK: - URL Processing
    private func processInitialURL() {
        if let path = AppDelegate.shared.getPathComponent() {
            guard isLoggedIn else {
                print("User not logged in, skipping URL processing")
                return
            }
            navigateBasedOnPath(path)
            AppDelegate.shared.resetURLProcessing()
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard isLoggedIn else { return }
        let path = url.host ?? ""
        navigateBasedOnPath(path)
    }
    
    private func navigateBasedOnPath(_ path: String) {
        switch path {
        case "timetable":
            selectedTab = 1
        case "assignment":
            selectedTab = 2
        case "bus":
            selectedTab = 0
            if let route = AppDelegate.shared.getQueryValue(for: "route"),
               let schedule = AppDelegate.shared.getQueryValue(for: "schedule") {
                let userInfo: [String: Any?] = ["route": route, "schedule": schedule]
                NotificationCenter.default.post(
                    name: Notification.Name("BusParametersFromURL"),
                    object: nil,
                    userInfo: userInfo as [AnyHashable: Any]
                )
            }
        case "print":
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootController = scene.windows.first?.rootViewController {
                let hostingController = UIHostingController(rootView: PrintSystemView.handleURLScheme())
                rootController.present(hostingController, animated: true)
            }
        default:
            break
        }
    }
}

// MARK: - Glass Header View
struct GlassHeaderView: View {
    @Binding var selectedTab: Int
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var appearanceManager: AppearanceManager
    
    var body: some View {
        GlassCard(variant: .elevated) {
            HStack {
                // Title based on selected tab
                HStack(spacing: 8) {
                    Image(systemName: headerIcon)
                        .font(.system(size: 20, weight: .semibold))
                    Text(headerTitle)
                        .font(.system(size: 20, weight: .bold))
                }
                
                Spacer()
                
                // Settings Button
                NavigationLink {
                    UserSettingsView(isLoggedIn: $isLoggedIn)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private var headerIcon: String {
        switch selectedTab {
        case 0: return "bus.fill"
        case 1: return "calendar"
        case 2: return "doc.text.fill"
        default: return "graduationcap.fill"
        }
    }
    
    private var headerTitle: String {
        switch selectedTab {
        case 0: return "バス時刻表"
        case 1: return "時間割"
        case 2: return "課題"
        default: return "TUTnext"
        }
    }
}

// MARK: - Glass Tab Bar
struct GlassTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach([(icon: "bus.fill", label: "バス", tag: 0),
                     (icon: "calendar", label: "時間割", tag: 1),
                     (icon: "doc.text.fill", label: "課題", tag: 2)], id: \.tag) { item in
                tabBarItem(item)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private func tabBarItem(_ item: (icon: String, label: String, tag: Int)) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = item.tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: selectedTab == item.tag ? .semibold : .regular))
                    .foregroundColor(selectedTab == item.tag ? .accentColor : .secondary)
                
                Text(item.label)
                    .font(.system(size: 11, weight: selectedTab == item.tag ? .semibold : .regular))
                    .foregroundColor(selectedTab == item.tag ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppearanceManager())
        .environmentObject(NotificationService.shared)
        .environmentObject(RatingService.shared)
        .environmentObject(ThemeManager.shared)
}
