import Foundation
import UIKit
import UserNotifications

/// 課題管理サービス
final class AssignmentService {
    static let shared = AssignmentService()
    private let apiService = APIService.shared
    private let userService = UserService.shared

    /// 課題データが更新された時の通知名
    static let assignmentsUpdatedNotification: Notification.Name = .assignmentsUpdated

    private init() {}

    // 実際のAPIを使用する場合の実装
    func getAssignments(completion: @escaping (Result<[Assignment], Error>) -> Void) {
        // APIエンドポイント
        let endpoint = "/kadai"
        let baseURL = "https://tama.qaq.tw"  // 実際のAPIのベースURL

        guard let url = URL(string: baseURL + endpoint) else {
            completion(
                .failure(
                    NSError(
                        domain: "AssignmentService", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        // ユーザー情報を取得
        guard let currentUser = userService.getCurrentUser(),
            let encryptedPassword = currentUser.encryptedPassword
        else {
            completion(
                .failure(
                    NSError(
                        domain: "AssignmentService", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "ユーザー情報が見つかりません"])))
            return
        }

        // APIリクエストの設定
        let body: [String: Any] = [
            "username": currentUser.username,
            "encryptedPassword": encryptedPassword
        ]
        let logTag = "AssignmentAPI"

        // URLRequestの作成
        guard let request = apiService.createRequest(url: url, method: "POST", body: body) else {
            completion(
                .failure(
                    NSError(
                        domain: "AssignmentService", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }

        // APIリクエストの実行
        apiService.request(
            request: request,
            logTag: logTag
        ) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(
                        .failure(
                            NSError(
                                domain: "AssignmentService", code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "データが取得できませんでした"])))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(AssignmentResponse.self, from: data)

                if response.status, let apiAssignments = response.data {
                    // APIAssignmentをAssignmentに変換
                    let assignments = apiAssignments.map { $0.toAssignment() }
                    DispatchQueue.main.async {
                        // 通知を送信
                        NotificationCenter.default.post(
                            name: AssignmentService.assignmentsUpdatedNotification,
                            object: nil,
                            userInfo: ["count": assignments.count]
                        )

                        // アプリのバッジを更新
                        self.updateApplicationBadge(count: assignments.count)

                        // 新しい課題を検知してローカル通知を送信
                        let newAssignments = self.detectNewAssignments(assignments)
                        if !newAssignments.isEmpty {
                            NotificationService.shared.sendNewAssignmentLocalNotifications(newAssignments)
                        }

                        // 締め切りリマインダーを再スケジュール
                        NotificationService.shared.scheduleAssignmentDeadlineNotifications(assignments)

                        completion(.success(assignments))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(
                            .failure(
                                NSError(
                                    domain: "AssignmentService", code: 3,
                                    userInfo: [NSLocalizedDescriptionKey: "APIエラー: データの取得に失敗しました"]))
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // アプリのバッジを更新するメソッド
    private func updateApplicationBadge(count: Int) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("通知許可がないため、バッジは更新しません")
                return
            }
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("バッジ更新エラー: \(error.localizedDescription)")
                } else {
                    print("アプリのバッジを更新しました: \(count)")
                }
            }
        }
    }

    // MARK: - 新課題検知

    /// 課題のフィンガープリントを生成する（idは毎回変わるためcourseId+title+dueDateで識別）
    private func makeFingerprint(_ assignment: Assignment) -> String {
        "\(assignment.courseId)-\(assignment.title)-\(Int(assignment.dueDate.timeIntervalSince1970))"
    }

    /// 前回との差分から新しい課題を検出し、フィンガープリントを保存する
    private func detectNewAssignments(_ assignments: [Assignment]) -> [Assignment] {
        let key = "assignment_fingerprints"
        let previous = Set((UserDefaults.standard.array(forKey: key) as? [String]) ?? [])
        let current = assignments.map { makeFingerprint($0) }

        // 保存
        UserDefaults.standard.set(current, forKey: key)

        // 初回（previous が空）は通知しない
        guard !previous.isEmpty else { return [] }

        return assignments.filter { !previous.contains(makeFingerprint($0)) }
    }

    // APNSからの課題数変更通知を処理するメソッド
    func handleAssignmentCountChangeNotification(userInfo: [AnyHashable: Any]) {
        // APNSから受け取った課題数
        guard let num = userInfo["num"] as? Int else {
            print("課題数変更通知の処理に失敗: 課題数情報がありません")
            return
        }

        print("APNSからの課題数変更通知を受信: 課題数=\(num)")

        // 通知を送信（UI更新用）
        NotificationCenter.default.post(
            name: AssignmentService.assignmentsUpdatedNotification,
            object: nil,
            userInfo: ["count": num]
        )

        // アプリのバッジを更新
        updateApplicationBadge(count: num)
    }
}
