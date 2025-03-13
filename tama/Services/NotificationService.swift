//
//  NotificationService.swift
//  tama
//
//  Created by AI Assistant on 2024/09/01.
//

import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // 初期化時にUserServiceからデバイストークンを取得
        self.deviceToken = UserService.shared.getDeviceToken()
    }
    
    // 通知権限をリクエスト
    func requestAuthorization() {
        print("通知権限をリクエストします")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    print("通知権限が許可されました。リモート通知を登録します。")
                    self.registerForRemoteNotifications()
                } else {
                    // 拒否された場合
                    print("通知権限が拒否されました。")
                    // 通知が拒否された場合、デバイストークンを削除
                    UserService.shared.clearDeviceToken()
                    self.deviceToken = nil
                }
                
                if let error = error {
                    print("通知権限リクエストエラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // リモート通知の登録
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // 通知権限ステータスの確認と必要に応じた再登録
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let wasAuthorized = self.isAuthorized
                self.isAuthorized = settings.authorizationStatus == .authorized
                
                // 通知権限の状態をログに出力
                print("通知権限の状態: \(settings.authorizationStatus.rawValue)")
                print("isAuthorized: \(self.isAuthorized)")
                
                // UserServiceからデバイストークンを取得して状態を更新
                self.deviceToken = UserService.shared.getDeviceToken()
                
                // 権限状態が変更された場合の処理
                if !wasAuthorized && self.isAuthorized {
                    // 以前は許可されていなかったが、今は許可されている場合
                    print("通知権限が新たに許可されました。")
                    
                    // デバイストークンがない場合は登録
                    if self.deviceToken == nil {
                        print("リモート通知を登録します。")
                        self.registerForRemoteNotifications()
                    }
                } else if wasAuthorized && !self.isAuthorized {
                    // 以前は許可されていたが、今は許可されていない場合
                    print("通知権限が取り消されました。")
                    
                    // デバイストークンがある場合は、サーバーから登録解除
                    if let token = self.deviceToken {
                        self.unregisterDeviceTokenFromServer(token: token)
                        // デバイストークンを削除
                        UserService.shared.clearDeviceToken()
                        self.deviceToken = nil
                    }
                }
            }
        }
    }
    
    // デバイストークンをサーバーに送信
    func sendDeviceTokenToServer(token: String, username: String) {
        print("デバイストークンをサーバーに送信: \(token) \(username)")
        // TODO: サーバーにデバイストークンを送信する実装
        // APIService.shared.registerDeviceToken(token: token) { result in
        //     switch result {
        //     case .success:
        //         print("デバイストークンの登録に成功しました")
        //     case .failure(let error):
        //         print("デバイストークンの登録に失敗しました: \(error.localizedDescription)")
        //     }
        // }
    }
    
    // デバイストークンをサーバーから登録解除
    func unregisterDeviceTokenFromServer(token: String) {
        print("デバイストークンをサーバーから登録解除: \(token)")
        // TODO: サーバーからデバイストークンを登録解除する実装
        // APIService.shared.unregisterDeviceToken(token: token) { result in
        //     switch result {
        //     case .success:
        //         print("デバイストークンの登録解除に成功しました")
        //     case .failure(let error):
        //         print("デバイストークンの登録解除に失敗しました: \(error.localizedDescription)")
        //     }
        // }
    }
    
    // アプリがフォアグラウンドに戻ったときに呼び出す
    func applicationWillEnterForeground() {
        checkAuthorizationStatus()
    }
    
    // 通知登録状態を確認するヘルパーメソッド
    var isRegistered: Bool {
        return isAuthorized && deviceToken != nil
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    // フォアグラウンドでの通知表示
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // 通知タップ時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // 通知のペイロードに基づいて適切な画面に遷移するなどの処理を実装
        print("通知がタップされました: \(userInfo)")
        completionHandler()
    }
}

// MARK: - AppDelegate拡張用メソッド
extension NotificationService {
    // デバイストークン取得成功時
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("デバイストークン取得成功: \(deviceToken)")
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceToken = token
        print("デバイストークン: \(token)")
        
        // UserServiceにデバイストークンを保存
        UserService.shared.saveDeviceToken(token)
        
        // サーバーにデバイストークンを送信
        sendDeviceTokenToServer(token: token, username: UserService.shared.getCurrentUser()?.username ?? "")
    }
    
    // デバイストークン取得失敗時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("リモート通知の登録に失敗しました: \(error.localizedDescription)")
        self.deviceToken = nil
        
        // 失敗した場合、UserServiceからデバイストークンを削除
        UserService.shared.clearDeviceToken()
    }
    
    // リモート通知受信時
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("バックグラウンドで通知を受信しました: \(userInfo)")
        // 必要に応じてデータを処理
        completionHandler(.newData)
    }
} 