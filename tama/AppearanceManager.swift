import SwiftUI

class AppearanceManager: ObservableObject {
    
    enum AppearanceColor: Int {
        case iSystem = 0
        case iHight = 1
        case iDark = 2
    }
    
    @Published var isDarkMode: Bool = false {
        didSet {
            if oldValue != isDarkMode {
                print("isDarkMode changed from \(oldValue) to \(isDarkMode)")
                // 明示的に変更を通知
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    @Published var type: AppearanceColor {
        didSet {
            print("Appearance type changed to: \(type)")
            
            // タイプに応じてダークモードを設定
            let newDarkMode: Bool
            switch type {
            case .iSystem:
                newDarkMode = (getCurrentInterfaceStyle() == .dark)
            case .iHight:
                newDarkMode = false
            case .iDark:
                newDarkMode = true
            }
            
            // 変更があった場合のみ更新（無限ループ防止）
            if isDarkMode != newDarkMode {
                isDarkMode = newDarkMode
            }
            
            // UserDefaultsに保存
            UserDefaults.standard.set(type.rawValue, forKey: "darkMode")
            print("isDarkMode set to: \(isDarkMode)")
            
            // 明示的に変更を通知（二重通知を防ぐためディスパッチで遅延）
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            // 全アプリに変更を通知するため通知を送信
            NotificationCenter.default.post(name: Notification.Name("AppearanceDidChangeNotification"), object: nil)
        }
    }
    
    init() {
        print("AppearanceManager initialized")
        
        // UserDefaultsから設定を読み込み
        type = AppearanceColor(rawValue: UserDefaults.standard.integer(forKey: "darkMode")) ?? .iSystem
        
        // 初期値を設定
        switch type {
        case .iSystem:
            isDarkMode = (getCurrentInterfaceStyle() == .dark)
        case .iHight:
            isDarkMode = false
        case .iDark:
            isDarkMode = true
        }
        
        print("Initial isDarkMode: \(isDarkMode)")
    }
    
    func getCurrentInterfaceStyle() -> UIUserInterfaceStyle {
        if #available(iOS 13.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle
        } else {
            return .light
        }
    }
    
    // システムのダークモード変更を監視
    func startObservingSystemAppearance() {
        // アプリがアクティブになったときに確認
        NotificationCenter.default.addObserver(self,
            selector: #selector(systemAppearanceChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        // カスタム通知も監視
        NotificationCenter.default.addObserver(self,
            selector: #selector(appearanceDidChange),
            name: Notification.Name("AppearanceDidChangeNotification"),
            object: nil)
        
        // トレイト変更（ダークモード切替など）の監視を設定
        if #available(iOS 13.0, *) {
            // UITraitCollectionのトレイト変更通知を監視
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UITraitCollectionDidChangeNotification"),
                object: nil,
                queue: .main) { [weak self] _ in
                    self?.systemAppearanceChanged()
                }
        }
    }
    
    @objc private func systemAppearanceChanged() {
        if type == .iSystem {
            let newDarkMode = (getCurrentInterfaceStyle() == .dark)
            if isDarkMode != newDarkMode {
                print("System appearance changed, updating isDarkMode to \(newDarkMode)")
                isDarkMode = newDarkMode
            }
        }
    }
    
    @objc private func appearanceDidChange() {
        print("Received appearance change notification")
        // 全アプリのビューを更新するためのヘルパー
        objectWillChange.send()
    }
} 