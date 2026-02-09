//
//  NotificationService
//  TUTnext
//
//  Service layer implementation using Core modules
//
import Foundation
import UserNotifications

/// Notification service protocol
public protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
    func registerForRemoteNotifications()
    func unregisterFromServer()
    func sendDeviceTokenToServer(token: String)
    func handleNotification(_ userInfo: [AnyHashable: Any])
    func checkAndRefreshDeviceToken()
}

/// Notification service implementation using Core modules
@MainActor
public final class NotificationService: NotificationServiceProtocol {
    public static let shared = NotificationService()
    
    private let userService: UserServiceProtocol
    private let apiService: APIServiceProtocol
    private let notificationCenter: NotificationCenter
    
    private init(
        userService: UserServiceProtocol = UserService.shared,
        apiService: APIServiceProtocol = APIService.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.userService = userService
        self.apiService = apiService
        self.notificationCenter = notificationCenter
    }
    
    public func requestAuthorization() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
        return granted
    }
    
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    public func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    public func unregisterFromServer() {
        guard let token = userService.currentUser?.deviceToken else { return }
        
        Task {
            do {
                // Call unregister API endpoint
                let endpoint = APIEndpoint(path: "/push/unregister", method: .post)
                let body = ["deviceToken": token]
                _ = try await apiService.requestJSON(endpoint, body: body)
                
                userService.clearDeviceToken()
            } catch {
                print("Failed to unregister from server: \(error)")
            }
        }
    }
    
    public func sendDeviceTokenToServer(token: String) {
        guard let user = userService.currentUser else { return }
        
        Task {
            do {
                let endpoint = APIEndpoint(path: "/push/send", method: .post)
                let body: [String: Any] = [
                    "username": user.id,
                    "deviceToken": token
                ]
                _ = try await apiService.requestJSON(endpoint, body: body)
                
                userService.saveDeviceToken(token)
            } catch {
                print("Failed to send device token: \(error)")
            }
        }
    }
    
    public func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle different notification types
        if let updateType = userInfo["updateType"] as? String {
            switch updateType {
            case "roomChange":
                handleRoomChangeNotification(userInfo: userInfo)
            case "kaidaiNumChange":
                handleAssignmentCountChangeNotification(userInfo: userInfo)
            default:
                break
            }
        }
        
        // Navigate to page if specified
        if let toPage = userInfo["toPage"] as? String {
            navigateToPage(toPage)
        }
    }
    
    public func checkAndRefreshDeviceToken() {
        // Check if token needs refresh (7-day interval)
        guard let lastRefresh = userService.lastTokenRefreshDate,
              Date().timeIntervalSince(lastRefresh) < 7 * 24 * 60 * 60 else {
            registerForRemoteNotifications()
            return
        }
    }
    
    private func handleRoomChangeNotification(userInfo: [AnyHashable: Any]) {
        guard let courseName = userInfo["name"] as? String,
              let newRoom = userInfo["room"] as? String else {
            return
        }
        
        // Post notification for room change
        notificationCenter.post(
            name: .roomChangeReceived,
            object: nil,
            userInfo: ["courseName": courseName, "newRoom": newRoom]
        )
    }
    
    private func handleAssignmentCountChangeNotification(userInfo: [AnyHashable: Any]) {
        guard let count = userInfo["num"] as? Int else { return }
        
        AssignmentService.shared.handleAssignmentCountChange(count: count)
    }
    
    private func navigateToPage(_ page: String) {
        notificationCenter.post(
            name: .navigateToPage,
            object: nil,
            userInfo: ["page": page]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification.request.content.userInfo)
        completionHandler()
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let roomChangeReceived = Notification.Name("RoomChangeReceived")
    static let navigateToPage = Notification.Name("NavigateToPage")
}
