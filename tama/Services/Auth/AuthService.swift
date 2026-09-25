import Foundation
import UIKit

/// 認証サービス
final class AuthService {
    static let shared = AuthService()

    private init() {}

    // MARK: - ログイン

    func login(
        account: String, password: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard
            let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/pk/Pky001Resource/login")
        else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""

        let requestBody: [String: Any] = [
            "productCd": "ap",
            "subProductCd": "apa",
            "loginUserId": account,
            "encryptedLoginPassword": "",
            "langCd": "ja",
            "data": [
                "loginUserId": account,
                "plainLoginPassword": password,
                "judgeLoginPossibleFlg": false,
                "deviceId": deviceId,
                "autoLoginAuthCd": ""
            ]
        ]

        guard var request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(AuthError.requestCreationFailed))
            return
        }
        request = HeaderService.shared.addCommonHeaders(to: request)

        let decoder: (Data) -> Result<[String: Any], Error> = { data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    completion(.success(json))
                    return .success(json)
                } else {
                    let error = AuthError.invalidResponse
                    completion(.failure(error))
                    return .failure(error)
                }
            } catch {
                completion(.failure(error))
                return .failure(error)
            }
        }

        APIService.shared.request(
            endpoint: url.absoluteString,
            body: requestBody,
            logTag: "ログイン",
            replacingPercentEncoding: false,
            decoder: decoder
        )(request)
    }

    // MARK: - 初期設定取得（ログイン後に呼ぶ）

    func firstSetting(
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let user = UserService.shared.getCurrentUser() else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        guard
            let url = URL(
                string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa001Resource/firstSetting")
        else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        let requestBody: [String: Any] = [
            "productCd": "ap",
            "subProductCd": "apa",
            "loginUserId": user.username,
            "encryptedLoginPassword": user.encryptedPassword ?? "",
            "langCd": "ja",
            "data": [
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "",
                "token": "",
                "keijiNoticeFlg": false,
                "jugyoNoticeFlg": false,
                "productIniFileDtoList": [
                    ["productCd": "AP", "section": "ATTEND_PUSH", "key": "PUSH_USE_FLAG"],
                    ["productCd": "AP", "section": "ATTEND_PUSH", "key": "PUSH_USE_FLAG_PARENT"]
                ]
            ]
        ]

        guard var request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(AuthError.requestCreationFailed))
            return
        }
        request = HeaderService.shared.addCommonHeaders(to: request)
        request = HeaderService.shared.addAuthHeaders(to: request)

        APIService.shared.request(
            request: request,
            logTag: "初期設定",
            replacingPercentEncoding: true
        ) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(AuthError.invalidResponse))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool,
                    success,
                    let responseData = json["data"] as? [String: Any]
                {
                    completion(.success(responseData))
                } else {
                    completion(.failure(AuthError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - 強制ログアウト（セッション期限切れ時）

    /// セッション期限切れ時にAPIコールなしでローカルデータをクリアする
    func forceLogout() {
        print("【認証】セッション期限切れによる強制ログアウト")

        if let deviceToken = NotificationService.shared.deviceToken {
            NotificationService.shared.unregisterDeviceTokenFromServer(token: deviceToken)
        }

        clearLocalSession()
    }

    // MARK: - ローカルセッションのクリア（ログアウト共通処理）

    /// ログアウト時にローカルのセッション・キャッシュ・Live Activity をすべて片付ける
    /// （通常ログアウトと強制ログアウトで共通）
    private func clearLocalSession() {
        // ユーザー情報を削除する前に、バックエンドの登録解除に使うユーザー名を控えておく
        let username = UserService.shared.getCurrentUser()?.username

        Task { @MainActor in
            // 監視タスクの停止・登録解除・push-to-start トークンの破棄（次回ログイン時に再登録させる）
            LiveActivityScheduler.shared.resetForLogout(username: username)
            // 前のユーザーの時間割キャッシュ（メモリ・共有 SwiftData）を削除し、ウィジェットを更新
            TimetableService.shared.clearCacheForLogout()
            // Live Activity をすべて終了
            await LiveActivityService.shared.endAllActivities()
        }

        CookieService.shared.clearCookies()
        // 課題・お知らせの控えとパスワードも clearCurrentUser 内で削除する
        UserService.shared.clearCurrentUser()
    }

    // MARK: - ログアウト

    func logout(
        userId: String, encryptedPassword: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard
            let url = URL(
                string: "https://next.tama.ac.jp/uprx/webapi/up/pk/Pky002Resource/logout")
        else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        let requestBody: [String: Any] = [
            "subProductCd": "apa",
            "plainLoginPassword": "",
            "loginUserId": userId,
            "langCd": "",
            "productCd": "ap",
            "encryptedLoginPassword": encryptedPassword
        ]

        guard var request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(AuthError.requestCreationFailed))
            return
        }
        request = HeaderService.shared.addCommonHeaders(to: request)
        request = HeaderService.shared.addAuthHeaders(to: request)

        if let deviceToken = NotificationService.shared.deviceToken {
            NotificationService.shared.unregisterDeviceTokenFromServer(token: deviceToken)
        }

        // ログアウトはローカル操作を優先する。
        // サーバー側ログアウトはベストエフォートで送信し、その成否に関わらず
        // ローカルセッションをクリアして完了を通知する。
        // （ネットワークエラー・セッション期限切れ・解析失敗でもログアウトが詰まらないように）
        let decoder: (Data) -> Result<Bool, Error> = { data in
            // サーバー応答はログ目的のみ。ローカルクリアと completion は下で無条件実行済み。
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let statusDto = json["statusDto"] as? [String: Any],
                let success = statusDto["success"] as? Bool, success {
                return .success(true)
            }
            return .failure(AuthError.invalidResponse)
        }

        APIService.shared.request(
            endpoint: url.absoluteString,
            body: requestBody,
            logTag: "ログアウト",
            replacingPercentEncoding: false,
            decoder: decoder
        )(request)

        // サーバー応答を待たずにローカルセッションを即時クリアし、UI を確実に遷移させる
        clearLocalSession()
        completion(.success(true))
    }
}
