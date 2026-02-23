import SafariServices
import SwiftUI

struct SafariWebView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    let url: URL

    // オプションの通知タイプを追加
    var dismissNotification: Notification.Name?

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.delegate = context.coordinator
        safariViewController.preferredBarTintColor = UIColor.systemBackground
        safariViewController.preferredControlTintColor = UIColor.label
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        uiViewController.preferredBarTintColor = UIColor.systemBackground
        uiViewController.preferredControlTintColor = UIColor.label
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
