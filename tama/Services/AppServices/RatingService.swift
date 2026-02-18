import Foundation
import StoreKit
import SwiftUI

/// アプリ評価リクエストサービス
final class RatingService: ObservableObject {
    static let shared = RatingService()

    // 評価リクエストの設定
    private let minimumLaunchCount = 10 // 最小起動回数
    private let minimumDaysSinceLastRequest = 30 // 最小間隔日数
    private let significantEventsThreshold = 5 // 重要操作回数の閾値

    private init() {}

    // MARK: - パブリックメソッド

    /// アプリ起動時に呼び出し
    func onAppLaunch() {
        incrementLaunchCount()
        checkAndRequestRating()
    }

    /// 重要イベントを記録（時間割表示、課題表示など）
    func recordSignificantEvent() {
        AppDefaults.significantEventsCount += 1
        print("RatingService: 重要イベントを記録しました。回数: \(AppDefaults.significantEventsCount)")

        // 重要イベント後も評価リクエストが可能かチェック
        checkAndRequestRating()
    }

    /// ユーザーが評価完了後に呼び出し
    func userDidRate() {
        AppDefaults.hasUserRated = true
        print("RatingService: ユーザーがアプリを評価しました")
    }

    /// 手動評価リクエスト（設定画面の「アプリを評価」ボタンなど）
    func requestRatingManually() {
        requestRating(force: true)
    }

    // MARK: - プライベートメソッド

    private func incrementLaunchCount() {
        AppDefaults.appLaunchCount += 1
        print("RatingService: アプリ起動回数: \(AppDefaults.appLaunchCount)")
    }

    private func checkAndRequestRating() {
        // ユーザーが既に評価済みの場合はリクエストしない
        if AppDefaults.hasUserRated {
            return
        }

        let shouldRequest = shouldRequestRating()
        if shouldRequest {
            requestRating()
        }
    }

    private func shouldRequestRating() -> Bool {
        let launchCount = AppDefaults.appLaunchCount
        let significantEventsCount = AppDefaults.significantEventsCount

        // 最小起動回数をチェック
        guard launchCount >= minimumLaunchCount else {
            print("RatingService: 起動回数 (\(launchCount)) が最小値 (\(minimumLaunchCount)) を下回っています")
            return false
        }

        // 重要イベント回数をチェック
        guard significantEventsCount >= significantEventsThreshold else {
            print("RatingService: 重要イベント回数 (\(significantEventsCount)) が閾値 (\(significantEventsThreshold)) を下回っています")
            return false
        }

        // 前回リクエストからの時間間隔をチェック
        if let lastRequestDate = AppDefaults.lastRatingRequestDate {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            guard daysSinceLastRequest >= minimumDaysSinceLastRequest else {
                print("RatingService: 前回リクエストから \(daysSinceLastRequest) 日しか経過していません（最小間隔: \(minimumDaysSinceLastRequest)日）")
                return false
            }
        }

        return true
    }

    private func requestRating(force: Bool = false) {
        // 強制リクエストでない場合は条件をチェック
        if !force && !shouldRequestRating() {
            return
        }

        // 最終リクエスト日時を更新
        AppDefaults.lastRatingRequestDate = Date()

        print("RatingService: App Store評価をリクエスト中")

        // メインスレッドでUI操作を実行
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }

    // MARK: - デバッグ・開発用メソッド

    /// 全ての評価関連データをリセット（開発デバッグ用のみ）
    func resetRatingData() {
        AppDefaults.resetRatingData()
        print("RatingService: 全ての評価データをリセットしました")
    }

    /// 現在の統計情報を取得（デバッグ用）
    func getDebugInfo() -> [String: Any] {
        return [
            "launchCount": AppDefaults.appLaunchCount,
            "significantEventsCount": AppDefaults.significantEventsCount,
            "hasUserRated": AppDefaults.hasUserRated,
            "lastRatingRequestDate": AppDefaults.lastRatingRequestDate as Any,
            "shouldRequestRating": shouldRequestRating()
        ]
    }
}

// MARK: - 開発デバッグ拡張
#if DEBUG
extension RatingService {
    /// 開発モードで評価リクエストを素早くトリガー（閾値を下げる）
    func enableDebugMode() {
        AppDefaults.appLaunchCount = minimumLaunchCount
        AppDefaults.significantEventsCount = significantEventsThreshold
        print("RatingService: デバッグモードが有効になりました - 閾値を満たしました")
    }

    /// ユーザーが長期間アプリを使用した状態をシミュレート
    func simulateExtensiveUsage() {
        AppDefaults.appLaunchCount = minimumLaunchCount + 5
        AppDefaults.significantEventsCount = significantEventsThreshold + 3
        print("RatingService: 長期使用状態をシミュレートしました")
    }
}
#endif
