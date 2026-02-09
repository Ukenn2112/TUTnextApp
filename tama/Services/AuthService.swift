import Foundation

/// 認証サービス
final class AuthService {
    static let shared = AuthService()

    private init() {}

    // ログイン処理を実行する関数
    func login(
        account: String, password: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        // API リクエストの準備
        guard
            let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/pk/Pky001Resource/login")
        else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "data": [
                "loginUserId": account,
                "plainLoginPassword": password,
            ]
        ]

        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(AuthError.requestCreationFailed))
            return
        }

        // カスタムデコーダー
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

        // APIリクエストの実行
        APIService.shared.request(
            endpoint: url.absoluteString,
            body: requestBody,
            logTag: "ログイン",
            replacingPercentEncoding: false,
            decoder: decoder
        )(request)
    }

    // ログアウト処理を実行する関数
    func logout(
        userId: String, encryptedPassword: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        // API リクエストの準備
        guard
            let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/pk/Pky002Resource/logout")
        else {
            completion(.failure(AuthError.invalidEndpoint))
            return
        }

        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "subProductCd": "apa",
            "plainLoginPassword": "",
            "loginUserId": userId,
            "langCd": "",
            "productCd": "ap",
            "encryptedLoginPassword": encryptedPassword,
        ]

        guard let request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(AuthError.requestCreationFailed))
            return
        }

        // デバイストークンを取得して通知登録を解除
        if let deviceToken = NotificationService.shared.deviceToken {
            NotificationService.shared.unregisterDeviceTokenFromServer(token: deviceToken)
        }

        // カスタムデコーダー
        let decoder: (Data) -> Result<Bool, Error> = { data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool
                {

                    // 常にCookieとユーザー情報をクリア（成功・失敗に関わらず）
                    CookieService.shared.clearCookies()
                    UserService.shared.clearCurrentUser()

                    if success {
                        completion(.success(true))
                        return .success(true)
                    } else {
                        // エラーメッセージがあれば取得
                        let errorMessage =
                            (statusDto["errorList"] as? [[String: Any]])?.first?["errorMessage"]
                            as? String ?? "Logout failed"
                        let error = AuthError.logoutFailed(errorMessage)
                        completion(.failure(error))
                        return .failure(error)
                    }
                } else {
                    // レスポンス解析失敗時もCookieとユーザー情報をクリア
                    CookieService.shared.clearCookies()
                    UserService.shared.clearCurrentUser()

                    let error = AuthError.invalidResponse
                    completion(.failure(error))
                    return .failure(error)
                }
            } catch {
                // エラー発生時もCookieとユーザー情報をクリア
                CookieService.shared.clearCookies()
                UserService.shared.clearCurrentUser()

                completion(.failure(error))
                return .failure(error)
            }
        }

        // APIリクエストの実行
        APIService.shared.request(
            endpoint: url.absoluteString,
            body: requestBody,
            logTag: "ログアウト",
            replacingPercentEncoding: false,
            decoder: decoder
        )(request)
    }
}

// 認証関連のエラー定義
enum AuthError: Error, LocalizedError {
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case invalidResponse
    case loginFailed(String)
    case logoutFailed(String)
    case userDataNotFound

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "APIエンドポイントが無効です"
        case .requestCreationFailed:
            return "リクエストデータの作成に失敗しました"
        case .noDataReceived:
            return "データが受信できませんでした"
        case .decodingFailed:
            return "レスポンスのデコードに失敗しました"
        case .invalidResponse:
            return "レスポンスの解析に失敗しました"
        case .loginFailed(let message):
            return message
        case .logoutFailed(let message):
            return message
        case .userDataNotFound:
            return "ユーザーデータが見つかりません"
        }
    }
}
