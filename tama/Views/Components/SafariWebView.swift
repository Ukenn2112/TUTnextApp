import SwiftUI
import SafariServices

struct SafariWebView: UIViewControllerRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        
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
} 