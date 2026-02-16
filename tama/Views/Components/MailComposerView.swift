import MessageUI
import SwiftUI

/// メール作成ビュー
struct MailComposerView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject("TUTnext アプリフィードバック")
        composer.setToRecipients(["admin@ukenn.top"])

        let appVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"
        let emailBody = """

            ------------------------------
            【システム情報】
            アプリバージョン: \(appVersion) (\(buildNumber))
            デバイス: \(UIDevice.current.model)
            OS: iOS \(UIDevice.current.systemVersion)
            ------------------------------
            """
        composer.setMessageBody(emailBody, isHTML: false)
        return composer
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.isShowing = false
        }
    }
}
