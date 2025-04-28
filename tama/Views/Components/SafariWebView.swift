import SafariServices
import SwiftUI

struct SafariWebView: UIViewControllerRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) private var presentationMode
    let url: URL

    // オプションの通知タイプを追加
    var dismissNotification: Notification.Name? = nil

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.delegate = context.coordinator

        // 根据当前主题设置颜色
        if colorScheme == .dark {
            // 暗黑模式
            safariViewController.preferredBarTintColor = UIColor.systemBackground
            safariViewController.preferredControlTintColor = .white
        } else {
            // 浅色模式
            safariViewController.preferredBarTintColor = .white
            safariViewController.preferredControlTintColor = .black
        }

        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 当主题变化时更新颜色
        if colorScheme == .dark {
            uiViewController.preferredBarTintColor = UIColor.systemBackground
            uiViewController.preferredControlTintColor = .white
        } else {
            uiViewController.preferredBarTintColor = .white
            uiViewController.preferredControlTintColor = .black
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariWebView

        init(_ parent: SafariWebView) {
            self.parent = parent
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // SafariViewが閉じられた時の処理
            parent.presentationMode.wrappedValue.dismiss()

            // 通知が設定されている場合に送信
            if let notification = parent.dismissNotification {
                NotificationCenter.default.post(name: notification, object: nil)
            }
        }
    }
}
