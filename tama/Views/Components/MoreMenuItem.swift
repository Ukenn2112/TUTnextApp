import SwiftUI

// MARK: - メニュー項目

/// 「その他」モードでタブバーに表示される項目
enum MoreMenuItem: CaseIterable, Identifiable {
    // 並び順がそのままタブバー上の位置になる
    case mobileSite
    case tamauni
    case teacherEmail
    case printSystem

    var id: Self { self }

    var title: String {
        switch self {
        case .mobileSite:
            return NSLocalizedString(
                "スマホサイト", comment: "「その他」メニュー項目：T-NEXTのスマートフォン向けサイトを開く")
        case .tamauni:
            return NSLocalizedString(
                "たまゆに", comment: "「その他」メニュー項目：Webサイト「たまゆに」（tamauniv.jp）を開く。サービス名のため固有名詞として扱う")
        case .teacherEmail:
            return NSLocalizedString(
                "教師メール", comment: "「その他」メニュー項目：教員のメールアドレス一覧を開く")
        case .printSystem:
            return NSLocalizedString(
                "印刷システム", comment: "「その他」メニュー項目：学内のプリンターで印刷するファイルをアップロードする画面を開く")
        }
    }

    var systemImage: String {
        switch self {
        case .mobileSite: return "smartphone"
        case .tamauni: return "globe"
        case .teacherEmail: return "envelope"
        case .printSystem: return "printer"
        }
    }

    /// 項目選択時に開くシートを生成する（スマホサイトはログイン情報付きのURLを都度組み立てる）
    func makeSheet() -> MoreMenuSheet? {
        switch self {
        case .mobileSite:
            return Self.createTnextURL().map { .webView($0) }
        case .tamauni:
            return Self.tamauniURL.map { .webView($0) }
        case .teacherEmail:
            return .teacherEmail
        case .printSystem:
            return .printSystem
        }
    }

    /// たまゆにのURL（固定の文字列だが、強制アンラップで落ちないよう Optional のまま扱う）
    private static let tamauniURL = URL(string: "https://tamauniv.jp")

    /// T-nextへのURLを生成する
    private static func createTnextURL() -> URL? {
        let user = UserService.shared.getCurrentUser()
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

// MARK: - シート種別

/// メニューから開くシートの種類
enum MoreMenuSheet: Identifiable {
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

    @ViewBuilder var content: some View {
        switch self {
        case .webView(let url):
            SafariWebView(url: url)
        case .teacherEmail:
            TeacherEmailListView()
        case .printSystem:
            PrintSystemView()
        }
    }
}
