import SwiftUI

struct HeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var isLoggedIn: Bool
    @State private var showingUserSettings = false
    @State private var user: User?
    let semester: Semester = .current  // 使用当前学期数据
    
    // ビュー表示時にユーザー情報を読み込む
    var body: some View {
        HStack(spacing: 8) {
            // 标题区域
            currentTitle
            
            Spacer()
            
            // 右侧按钮
            HStack(spacing: 16) {
                // 通知铃铛
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                
                // 用户头像
                Button(action: { showingUserSettings = true }) {
                    Text(getInitials())
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(isLoggedIn: $isLoggedIn)
        }
        .onAppear {
            // ビュー表示時にUserServiceからユーザー情報を取得
            loadUserData()
        }
    }
    
    // ユーザーデータを読み込む
    private func loadUserData() {
        user = UserService.shared.getCurrentUser()
    }
    
    // 获取当前标题
    private var currentTitle: some View {
        Group {
            if selectedTab == 1 {
                HStack(spacing: 4) {
                    Text(semester.shortYearString)
                        .font(.system(size: 15, weight: .bold))
                        .padding(6)
                        .background(Color.pink.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .cornerRadius(10)
                    
                    Text(semester.fullDisplayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
            } else {
                Text(getTitleText())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
            }
        }
    }
    
    private func getTitleText() -> String {
        switch selectedTab {
        case 0: return "スクールバス"
        case 2: return "课题"
        case 3: return "揭示板"
        default: return ""
        }
    }
    
    // イニシャルを取得（名前の頭文字、最大2文字）
    private func getInitials() -> String {
        guard let fullName = user?.fullName else { return "?" }
        
        // 空白で分割して最初の部分を取得
        let nameParts = fullName.split(separator: " ")
        if let firstPart = nameParts.first {
            // 最初の部分から最大2文字を取得
            let initialChars = String(firstPart.prefix(2))
            return initialChars
        }
        
        return "?"
    }
}

#Preview {
    HeaderView(selectedTab: .constant(1), isLoggedIn: .constant(true))
}
