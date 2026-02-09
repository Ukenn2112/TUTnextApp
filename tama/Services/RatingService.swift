import Foundation
import StoreKit
import SwiftUI

/// アプリ評価リクエストサービス
final class RatingService: ObservableObject {
    static let shared = RatingService()
    
    // UserDefaultsのキー
    private let appLaunchCountKey = "AppLaunchCount"
    private let lastRatingRequestDateKey = "LastRatingRequestDate"
    private let hasUserRatedKey = "HasUserRated"
    private let significantEventsCountKey = "SignificantEventsCount"
    
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
        let currentCount = UserDefaults.standard.integer(forKey: significantEventsCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: significantEventsCountKey)
        print("RatingService: 重要イベントを記録しました。回数: \(currentCount + 1)")
        
        // 重要イベント後も評価リクエストが可能かチェック
        checkAndRequestRating()
    }
    
    /// ユーザーが評価完了後に呼び出し
    func userDidRate() {
        UserDefaults.standard.set(true, forKey: hasUserRatedKey)
        print("RatingService: ユーザーがアプリを評価しました")
    }
    
    /// 手動評価リクエスト（設定画面の「アプリを評価」ボタンなど）
    func requestRatingManually() {
        requestRating(force: true)
    }
    
    // MARK: - プライベートメソッド
    
    private func incrementLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: appLaunchCountKey)
        print("RatingService: アプリ起動回数: \(currentCount + 1)")
    }
    
    private func checkAndRequestRating() {
        // ユーザーが既に評価済みの場合はリクエストしない
        if UserDefaults.standard.bool(forKey: hasUserRatedKey) {
            return
        }
        
        let shouldRequest = shouldRequestRating()
        if shouldRequest {
            requestRating()
        }
    }
    
    private func shouldRequestRating() -> Bool {
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        let significantEventsCount = UserDefaults.standard.integer(forKey: significantEventsCountKey)
        
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
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastRatingRequestDateKey) as? Date {
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
        UserDefaults.standard.set(Date(), forKey: lastRatingRequestDateKey)
        
        print("RatingService: App Store評価をリクエスト中")
        
        // メインスレッドでUI操作を実行
        DispatchQueue.main.async {
            // iOS 14.0+では新しいAPIを使用
            if #available(iOS 14.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            } else {
                // iOS 14未満では旧APIを使用
                SKStoreReviewController.requestReview()
            }
        }
    }
    
    // MARK: - デバッグ・開発用メソッド
    
    /// 全ての評価関連データをリセット（開発デバッグ用のみ）
    func resetRatingData() {
        UserDefaults.standard.removeObject(forKey: appLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: lastRatingRequestDateKey)
        UserDefaults.standard.removeObject(forKey: hasUserRatedKey)
        UserDefaults.standard.removeObject(forKey: significantEventsCountKey)
        print("RatingService: 全ての評価データをリセットしました")
    }
    
    /// 現在の統計情報を取得（デバッグ用）
    func getDebugInfo() -> [String: Any] {
        return [
            "launchCount": UserDefaults.standard.integer(forKey: appLaunchCountKey),
            "significantEventsCount": UserDefaults.standard.integer(forKey: significantEventsCountKey),
            "hasUserRated": UserDefaults.standard.bool(forKey: hasUserRatedKey),
            "lastRatingRequestDate": UserDefaults.standard.object(forKey: lastRatingRequestDateKey) as? Date ?? "Never",
            "shouldRequestRating": shouldRequestRating()
        ]
    }
}

// MARK: - 開発デバッグ拡張
#if DEBUG
extension RatingService {
    /// 開発モードで評価リクエストを素早くトリガー（閾値を下げる）
    func enableDebugMode() {
        UserDefaults.standard.set(minimumLaunchCount, forKey: appLaunchCountKey)
        UserDefaults.standard.set(significantEventsThreshold, forKey: significantEventsCountKey)
        print("RatingService: デバッグモードが有効になりました - 閾値を満たしました")
    }
    
    /// ユーザーが長期間アプリを使用した状態をシミュレート
    func simulateExtensiveUsage() {
        UserDefaults.standard.set(minimumLaunchCount + 5, forKey: appLaunchCountKey)
        UserDefaults.standard.set(significantEventsThreshold + 3, forKey: significantEventsCountKey)
        print("RatingService: 長期使用状態をシミュレートしました")
    }
}
#endif
