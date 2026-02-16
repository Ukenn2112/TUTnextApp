import SwiftUI

// MARK: - その他メニューボタン

/// タブバー横に配置されるコンテキストメニュー表示ボタン
struct MoreMenuButton: View {

    // MARK: - プロパティ

    private let menuLabel: AnyView
    @State private var showWebView = false
    @State private var webViewURL: URL?
    @State private var user: User?
    @State private var showSheet = false
    @State private var sheetContent: AnyView?

    // MARK: - イニシャライザ

    init() {
        self.menuLabel = AnyView(
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        )
    }

    init<L: View>(@ViewBuilder label: () -> L) {
        self.menuLabel = AnyView(label())
    }

    // MARK: - ボディ

    var body: some View {
        Menu {
            // Web系アクション
            Section {
                Button(action: {
                    webViewURL = URL(string: "https://tamauniv.jp/campuslife/calendar")
                    showWebView = true
                }) {
                    Label(NSLocalizedString("年間予定", comment: ""), systemImage: "calendar.badge.clock")
                }

                Button(action: {
                    if let tnextURL = createTnextURL() {
                        webViewURL = tnextURL
                        showWebView = true
                    }
                }) {
                    Label(NSLocalizedString("スマホサイト", comment: ""), systemImage: "smartphone")
                }

                Button(action: {
                    webViewURL = URL(string: "https://tamauniv.jp")
                    showWebView = true
                }) {
                    Label(NSLocalizedString("たまゆに", comment: ""), systemImage: "globe")
                }
            }

            // アプリ内機能
            Section {
                Button(action: {
                    showSheet = true
                    sheetContent = AnyView(TeacherEmailListView())
                }) {
                    Label(NSLocalizedString("教師メール", comment: ""), systemImage: "envelope")
                }

                Button(action: {
                    showSheet = true
                    sheetContent = AnyView(PrintSystemView())
                }) {
                    Label(NSLocalizedString("印刷システム", comment: ""), systemImage: "printer")
                }
            }
        } label: {
            menuLabel
        }
        .sheet(isPresented: $showWebView) {
            if let url = webViewURL {
                SafariWebView(url: url)
            }
        }
        .sheet(isPresented: $showSheet) {
            sheetContent
        }
        .onAppear {
            user = UserService.shared.getCurrentUser()
        }
    }

    // MARK: - プライベートメソッド

    /// T-nextへのURLを生成する
    private func createTnextURL() -> URL? {
        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "autoLoginAuthCd": "",
            "encryptedPassword": user?.encryptedPassword ?? "",
            "userId": user?.username ?? "",
            "parameterMap": ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        let encodedLoginInfo = jsonString.webAPIEncoded

        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }
}

// MARK: - プレビュー

#Preview {
    MoreMenuButton()
}
