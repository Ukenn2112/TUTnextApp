import SwiftUI

struct TabBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Divider()
                .background(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.2))
            
            // 标签栏
            HStack {
                TabBarButton(
                    image: "bus",
                    text: NSLocalizedString("バス", comment: "底部tab"),
                    isSelected: selectedTab == 0,
                    colorScheme: colorScheme,
                    action: { selectedTab = 0 }
                )
                
                TabBarButton(
                    image: "calendar",
                    text: NSLocalizedString("時間割", comment: "底部tab"),
                    isSelected: selectedTab == 1,
                    colorScheme: colorScheme,
                    action: { selectedTab = 1 }
                )
                
                TabBarButton(
                    image: "pencil.line",
                    text: NSLocalizedString("課題", comment: "底部tab"),
                    isSelected: selectedTab == 2,
                    colorScheme: colorScheme,
                    action: { selectedTab = 2 }
                )
            }
            .padding(.vertical, 6)
            .background(Color(UIColor.systemBackground))
            
            // 底部安全区域占位
            if getSafeAreaBottom() > 0 {
                Color(UIColor.systemBackground)
                    .frame(height: 0)
            }
        }
    }
    
    // 获取安全区域底部高度
    private func getSafeAreaBottom() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}

struct TabBarButton: View {
    let image: String
    let text: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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

#Preview {
    TabBarView(selectedTab: .constant(1))
} 
