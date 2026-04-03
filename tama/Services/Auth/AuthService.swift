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

        // Live Activity をすべて終了
        Task { @MainActor in
            await LiveActivityService.shared.endAllActivities()
        }

        let decoder: (Data) -> Result<Bool, Error> = { data in
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool
                {
                    CookieService.shared.clearCookies()
                    UserService.shared.clearCurrentUser()

                    if success {
                        completion(.success(true))
                        return .success(true)
                    } else {
                        let errorMessage =
                            (statusDto["errorList"] as? [[String: Any]])?.first?["errorMessage"]
                            as? String ?? "Logout failed"
                        let error = AuthError.logoutFailed(errorMessage)
                        completion(.failure(error))
                        return .failure(error)
                    }
                } else {
                    CookieService.shared.clearCookies()
                    UserService.shared.clearCurrentUser()
                    let error = AuthError.invalidResponse
                    completion(.failure(error))
                    return .failure(error)
                }
            } catch {
                CookieService.shared.clearCookies()
                UserService.shared.clearCurrentUser()
                completion(.failure(error))
                return .failure(error)
            }
        }

        APIService.shared.request(
            endpoint: url.absoluteString,
            body: requestBody,
            logTag: "ログアウト",
            replacingPercentEncoding: false,
            decoder: decoder
        )(request)
    }
}
