import SwiftUI
import UIKit

/// アプリの外観（ダークモード等）を管理するクラス
///
/// UIWindowの `overrideUserInterfaceStyle` を使用して外観を切り替える。
/// この方式はSheet・Alert・ActionSheet等すべてのUIに確実に適用される。
final class AppearanceManager: ObservableObject {

    // MARK: - 列挙型

    /// 外観モードの種類
    enum AppearanceMode: Int {
        case system = 0
        case light = 1
        case dark = 2
    }

    // MARK: - プロパティ

    @Published var mode: AppearanceMode

    // MARK: - UserDefaultsキー

    private enum DefaultsKey {
        static let darkMode = "darkMode"
    }

    // MARK: - 初期化

    init() {
        let savedRawValue = UserDefaults.standard.integer(forKey: DefaultsKey.darkMode)
        self.mode = AppearanceMode(rawValue: savedRawValue) ?? .system
    }

    // MARK: - 公開メソッド

    /// 外観モードを変更する
    func setMode(_ newMode: AppearanceMode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: DefaultsKey.darkMode)
        applyAppearance()
    }

    /// 現在のモードをすべてのウィンドウに適用する
    func applyAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }

        let style: UIUserInterfaceStyle
        switch mode {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }

        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = style
        }
    }
}
