import SwiftUI

struct HeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    @Binding var isLoggedIn: Bool
    @State private var showingUserSettings = false
    @State private var user: User?
    @State private var showSafariView = false
    @State private var keijiBoardURL: URL?
    @State private var semester: Semester = .current  // 使用当前学期数据
    
    // NotificationCenterを使用してUserDefaultsの変更を監視
    private let userDefaultsObserver = NotificationCenter.default
        .publisher(for: UserDefaults.didChangeNotification)
    
    // ビュー表示時にユーザー情報を読み込む
    var body: some View {
        HStack(spacing: 8) {
            // 标题区域
            currentTitle
            
            Spacer()
            
            // 右侧按钮
            HStack(spacing: 16) {
                // 掲示板
                Button(action: { showSafariView = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                        
                        // 未読通知バッジ
                        if let unreadCount = user?.allKeijiMidokCnt, unreadCount > 0 {
                            let displayText = unreadCount > 99 ? "99+" : "\(unreadCount)"
                            
                            Text(displayText)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .offset(x: -10, y: 14)
                                .animation(.spring(), value: unreadCount)
                        }
                    }
                }
                .offset(y: -2)
                
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
        .sheet(isPresented: $showSafariView, onDismiss: {
            // シートが閉じられた時（下スワイプでも）に実行される
            NotificationCenter.default.post(name: .announcementSafariDismissed, object: nil)
        }) {
            // 掲示板SafariViewが閉じられた時も通知を送信するように修正
            SafariWebView(
                url: createKeijiBoardURL() ?? URL(string: "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml")!,
                dismissNotification: .announcementSafariDismissed
            )
        }
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(isLoggedIn: $isLoggedIn)
        }
        .onAppear {
            // ビュー表示時にUserServiceからユーザー情報を取得
            loadUserData()
            // TimetableServiceから学期情報を取得
            semester = TimetableService.shared.currentSemester
        }
        .onReceive(userDefaultsObserver) { _ in
            // UserDefaultsが変更されたときにユーザー情報を再読み込み
            loadUserData()
        }
        .onReceive(TimetableService.shared.$currentSemester) { updatedSemester in
            // 学期情報が更新されたときに反映
            semester = updatedSemester
        }
    }
    
    // 掲示板URLを生成する関数
    private func createKeijiBoardURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else {
            return nil
        }
        
        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "funcId": "Bsd507",
            "autoLoginAuthCd": "",
            "formId": "Bsd50701",
            "encryptedPassword": encryptedPassword,
            "userId": user.username,
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
    
    // ユーザーデータを読み込む
    private func loadUserData() {
        // UserDefaultsから直接データを取得して最新の状態を確保
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let updatedUser = try? JSONDecoder().decode(User.self, from: userData) {
            // 前回と異なる場合のみ更新（特に未読通知数が変わった場合）
            if user?.allKeijiMidokCnt != updatedUser.allKeijiMidokCnt {
                print("未読通知数が更新されました: \(updatedUser.allKeijiMidokCnt ?? 0)")
                user = updatedUser
            } else if user == nil {
                user = updatedUser
            }
        } else {
            // UserServiceからも取得を試みる
            user = UserService.shared.getCurrentUser()
        }
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
        case 0: return NSLocalizedString("スクールバス", comment: "顶部tab")
        case 2: return NSLocalizedString("课题", comment: "顶部tab")
        default: return ""
        }
    }
    
    // イニシャルを取得（名前の頭文字、最大2文字）
    private func getInitials() -> String {
        guard let fullName = user?.fullName else { return "?" }
        
        // 空白で分割して最初の部分を取得
        let nameParts = fullName.split(separator: "　")
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
