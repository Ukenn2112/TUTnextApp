import SwiftUI

struct TabBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var showWebView = false
    @State private var webViewURL: URL?
    @State private var user: User?
    @FocusState private var isFocused: Bool
    
    private func collapseWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Divider()
                .background(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.2))
            
            // 可滑动的内容区域
            VStack(spacing: 0) {
                // 拖动指示器
                ZStack {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(isExpanded ? 0.5 : 0.3))
                        .frame(width: 36, height: 5)
                        .padding(.vertical, 12)
                }
                .contentShape(Rectangle().size(CGSize(width: 60, height: 30))) // 明確なタップ領域の設定
                .gesture(
                    DragGesture(minimumDistance: 10) // 最小拖动距离，防止轻触误操作
                        .onEnded { value in
                            if abs(value.translation.height) > 5 { // 垂直方向の移動が5ポイント以上あるときのみ反応
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isExpanded.toggle()
                                }
                            }
                        }
                )
                .onTapGesture {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred() // タップ時に触覚フィードバックを提供
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
                .focused($isFocused)
                
                // 第二层级功能按钮
                if isExpanded {
                    HStack(spacing: 30) {
                        SecondaryTabButton(
                            image: "calendar.badge.clock",
                            text: NSLocalizedString("年間予定", comment: ""),
                            colorScheme: colorScheme
                        ) {
                            webViewURL = URL(string: "https://tamauniv.jp/campuslife/calendar")
                            showWebView = true
                            collapseWithAnimation()
                        }
                        
                        SecondaryTabButton(
                            image: "smartphone",
                            text: NSLocalizedString("スマホサイト", comment: ""),
                            colorScheme: colorScheme
                        ) {
                            if let tnextURL = createTnextURL() {
                                webViewURL = tnextURL
                                showWebView = true
                                collapseWithAnimation()
                            }
                        }
                        
                        SecondaryTabButton(
                            image: "globe",
                            text: NSLocalizedString("たまゆに", comment: ""),
                            colorScheme: colorScheme
                        ) {
                            webViewURL = URL(string: "https://tamauniv.jp")
                            showWebView = true
                            collapseWithAnimation()
                        }
                        
                        SecondaryTabButton(
                            image: "printer",
                            text: NSLocalizedString("印刷システム", comment: ""),
                            colorScheme: colorScheme
                        ) {
                            webViewURL = URL(string: "https://cloudodp.fujifilm.com/guestweb/?#/login")
                            showWebView = true
                            collapseWithAnimation()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .focused($isFocused)
                }
                
                // 主标签栏
                HStack {
                    TabBarButton(
                        image: "bus",
                        text: NSLocalizedString("バス", comment: "底部tab"),
                        isSelected: selectedTab == 0,
                        colorScheme: colorScheme,
                        action: { 
                            selectedTab = 0
                            collapseWithAnimation()
                        }
                    )
                    
                    TabBarButton(
                        image: "calendar",
                        text: NSLocalizedString("時間割", comment: "底部tab"),
                        isSelected: selectedTab == 1,
                        colorScheme: colorScheme,
                        action: { 
                            selectedTab = 1
                            collapseWithAnimation()
                        }
                    )
                    
                    TabBarButton(
                        image: "pencil.line",
                        text: NSLocalizedString("課題", comment: "底部tab"),
                        isSelected: selectedTab == 2,
                        colorScheme: colorScheme,
                        action: { 
                            selectedTab = 2
                            collapseWithAnimation()
                        }
                    )
                }
                .padding(.vertical, 6)
            }
            .background(Color(UIColor.systemBackground))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.height > threshold && isExpanded {
                            collapseWithAnimation()
                        } else if value.translation.height < -threshold && !isExpanded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded = true
                            }
                        }
                    }
            )
            .onChange(of: isFocused) { oldValue, newValue in
                if !newValue && isExpanded {
                    collapseWithAnimation()
                }
            }
            
            // 底部安全区域占位
            if getSafeAreaBottom() > 0 {
                Color(UIColor.systemBackground)
                    .frame(height: 0)
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = webViewURL {
                SafariWebView(url: url)
            }
        }
        .onAppear {
            loadUserData()
        }
    }
    
    // 获取安全区域底部高度
    private func getSafeAreaBottom() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
    
    // ユーザーデータの読み込み
    private func loadUserData() {
        user = UserService.shared.getCurrentUser()
    }
    
    // T-nextへのURLを生成する関数
    private func createTnextURL() -> URL? {
        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "autoLoginAuthCd": "",
            "encryptedPassword": user?.encryptedPassword ?? "",
            "userId": user?.username ?? "",
            "parameterMap": ""
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        // カスタムエンコーディング
        let customEncoded = jsonString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "'", with: "%27")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: ",", with: "%2C")
            .replacingOccurrences(of: "/", with: "%2F")
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ";", with: "%3B")
            .replacingOccurrences(of: "=", with: "%3D")
            .replacingOccurrences(of: "?", with: "%3F")
            .replacingOccurrences(of: "{", with: "%7B")
            .replacingOccurrences(of: "}", with: "%7D")
        
        let encodedLoginInfo = customEncoded
            .replacingOccurrences(of: "%2522", with: "%22")
            .replacingOccurrences(of: "%255C", with: "%5C")
        
        let urlString = "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }
}

struct TabBarButton: View {
    let image: String
    let text: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            feedbackGenerator.impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: image)
                    .font(.system(size: 20))
                Text(text)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? 
                           (colorScheme == .dark ? .white : .black) :
                           .secondary)
        }
    }
}

struct SecondaryTabButton: View {
    let image: String
    let text: String
    let colorScheme: ColorScheme
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = false
                }
            }
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: image)
                    .font(.system(size: 23, weight: .medium))
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
    }
}

#Preview {
    TabBarView(selectedTab: .constant(1))
} 
