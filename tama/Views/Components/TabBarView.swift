import SwiftUI

// MARK: - シート種別

/// メニューから開くシートの種類
private enum MenuSheet: Identifiable {
    case webView(URL)
    case teacherEmail
    case printSystem

    var id: String {
        switch self {
        case .webView(let url): return "web_\(url.absoluteString)"
        case .teacherEmail: return "teacherEmail"
        case .printSystem: return "printSystem"
        }
    }
}

// MARK: - その他メニューボタン

/// タブバー横に配置されるコンテキストメニュー表示ボタン
struct MoreMenuButton: View {

    // MARK: - プロパティ

    private let menuLabel: AnyView
    @State private var activeSheet: MenuSheet?
    @State private var user: User?

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
                    activeSheet = .webView(URL(string: "https://tamauniv.jp/campuslife/calendar")!)
                }) {
                    Label(NSLocalizedString("年間予定", comment: ""), systemImage: "calendar.badge.clock")
                }

                Button(action: {
                    if let tnextURL = createTnextURL() {
                        activeSheet = .webView(tnextURL)
                    }
                }) {
                    Label(NSLocalizedString("スマホサイト", comment: ""), systemImage: "smartphone")
                }

                Button(action: {
                    activeSheet = .webView(URL(string: "https://tamauniv.jp")!)
                }) {
                    Label(NSLocalizedString("たまゆに", comment: ""), systemImage: "globe")
                }
            }

            // アプリ内機能
            Section {
                Button(action: {
                    activeSheet = .teacherEmail
                }) {
                    Label(NSLocalizedString("教師メール", comment: ""), systemImage: "envelope")
                }

                Button(action: {
                    activeSheet = .printSystem
                }) {
                    Label(NSLocalizedString("印刷システム", comment: ""), systemImage: "printer")
                }
            }
        } label: {
            menuLabel
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .webView(let url):
                SafariWebView(url: url)
            case .teacherEmail:
                TeacherEmailListView()
            case .printSystem:
                PrintSystemView()
            }
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
