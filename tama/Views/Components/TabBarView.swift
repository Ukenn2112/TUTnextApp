import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Divider()
            
            // 标签栏
            HStack {
                TabBarButton(
                    image: "bus",
                    text: "バス",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                TabBarButton(
                    image: "calendar",
                    text: "時間割",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                TabBarButton(
                    image: "pencil.line",
                    text: "課題",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                
                TabBarButton(
                    image: "list.clipboard",
                    text: "揭示板",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
            }
            .padding(.vertical, 6)
            .background(Color.white)
            
            // 底部安全区域占位
            if getSafeAreaBottom() > 0 {
                Color.white
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
            .foregroundColor(isSelected ? .black : .gray)
        }
    }
}

#Preview {
    TabBarView(selectedTab: .constant(1))
} 
