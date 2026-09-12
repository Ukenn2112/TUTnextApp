import Foundation
import UIKit

/// 時間割カレンダー購読サービス
///
/// `webcal://` URL を開くことで、iOS 標準の「カレンダーを照会」シートを表示し、
/// ユーザーがワンタップで時間割カレンダーを購読できるようにする。
final class CalendarSubscriptionService {
    /// シングルトンインスタンス
    static let shared = CalendarSubscriptionService()

    /// 購読エンドポイントのホスト
    private let host = "tama.qaq.tw"

    /// 購読エンドポイントのパス
    private let path = "/schedule"

    /// パスワードを保存していない場合に開くフォールバック用 Web ページ
    let fallbackWebPageURL = "https://tama.qaq.tw/"

    private init() {}

    // MARK: - パブリックプロパティ

    /// 再入力なしで直接購読できるかどうか
    var canSubscribeDirectly: Bool {
        guard let username = UserService.shared.getCurrentUser()?.username, !username.isEmpty,
            let password = UserService.shared.getPassword(), !password.isEmpty
        else {
            return false
        }
        return true
    }

    // MARK: - パブリックメソッド

    /// 購読用の webcal:// URL を組み立てる
    func subscriptionURL() -> URL? {
        guard let username = UserService.shared.getCurrentUser()?.username, !username.isEmpty,
            let password = UserService.shared.getPassword(), !password.isEmpty
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "webcal"
        components.host = host
        components.path = path

        // URLComponents の既定のエンコードでは `+` や `&` などが素通りしてしまうため、
        // 厳密な許可文字セットで自前でパーセントエンコードする
        guard let encodedUsername = Self.percentEncoded(username),
            let encodedPassword = Self.percentEncoded(password)
        else {
            return nil
        }
        components.percentEncodedQuery = "username=\(encodedUsername)&password=\(encodedPassword)"

        return components.url
    }

    /// カレンダー購読シートを表示する
    @MainActor
    func subscribe(completion: @escaping (Bool) -> Void) {
        guard let url = subscriptionURL() else {
            completion(false)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            completion(success)
        }
    }

    // MARK: - プライベートメソッド

    /// クエリ値を厳密にパーセントエンコードする
    private static func percentEncoded(_ value: String) -> String? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
