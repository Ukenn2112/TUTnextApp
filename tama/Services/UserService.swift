import Foundation

class UserService {
    static let shared = UserService()

    private init() {}

    // ユーザーデータを保存
    func saveUser(_ user: User, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if let encodedData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encodedData, forKey: "currentUser")
                // 確実に保存が完了するようにsynchronizeを呼び出す
                UserDefaults.standard.synchronize()
                // 保存完了後にコールバックを実行
                completion?()
            }
        }
    }

    // デバイストークンを保存
    func saveDeviceToken(_ token: String) {
        DispatchQueue.main.async {
            UserDefaults.standard.set(token, forKey: "deviceToken")
        }
    }

    // デバイストークンを取得
    func getDeviceToken() -> String? {
        return UserDefaults.standard.string(forKey: "deviceToken")
    }

    // デバイストークンを削除
    func clearDeviceToken() {
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: "deviceToken")
        }
    }

    // ユーザーデータを取得
    func getCurrentUser() -> User? {
        if let userData = UserDefaults.standard.data(forKey: "currentUser") {
            return try? JSONDecoder().decode(User.self, from: userData)
        }
        return nil
    }

    // ユーザーデータを削除（ログアウト時）
    func clearCurrentUser() {
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: "currentUser")
        }
    }

    // 全未読揭示数を更新
    func updateAllKeijiMidokCnt(keijiCnt: Int, completion: (() -> Void)? = nil) {
        if var user = getCurrentUser() {
            user.allKeijiMidokCnt = keijiCnt
            saveUser(user) {
                completion?()
            }
        } else {
            completion?()
        }
    }

    // APIレスポンスからユーザーオブジェクトを作成
    func createUser(from userData: [String: Any]) -> User? {
        guard let userId = userData["userId"] as? String,
            let userName = userData["userName"] as? String,
            let gaksekiCd = (userData["gaksekiCd"] as? String) ?? (userData["jinjiCd"] as? String),
            let encryptedPassword = userData["encryptedPassword"] as? String
        else {
            return nil
        }
        print("【ユーザー作成】encryptedPassword: \(encryptedPassword)")

        // パスワードをURLエンコードする
        let encodedPassword =
            encryptedPassword
            .replacingOccurrences(of: "/", with: "%2F")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "=", with: "%3D")

        print("【ユーザー作成】encodedPassword: \(encodedPassword)")
        return User(
            id: gaksekiCd,
            username: userId,
            fullName: userName,
            encryptedPassword: encodedPassword,
            allKeijiMidokCnt: 0
        )
    }
}
