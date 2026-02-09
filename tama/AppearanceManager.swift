import SwiftUI

/// アプリの外観（ダークモード等）を管理するクラス
final class AppearanceManager: ObservableObject {

    // MARK: - 列挙型

    /// 外観モードの種類
    enum AppearanceMode: Int {
        case system = 0
        case light = 1
        case dark = 2
    }

    // MARK: - プロパティ

    @Published var isDarkMode: Bool = false
    @Published var mode: AppearanceMode

    /// SwiftUIの `preferredColorScheme` に渡すための計算プロパティ
    var colorSchemeOverride: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - UserDefaultsキー

    private enum DefaultsKey {
        static let darkMode = "darkMode"
    }

    // MARK: - 初期化

    init() {
        let savedRawValue = UserDefaults.standard.integer(forKey: DefaultsKey.darkMode)
        let savedMode = AppearanceMode(rawValue: savedRawValue) ?? .system
        self.mode = savedMode

        switch savedMode {
        case .system:
            isDarkMode = Self.currentSystemIsDark
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        }
    }

    // MARK: - 公開メソッド

    /// 外観モードを変更する
    func setMode(_ newMode: AppearanceMode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: DefaultsKey.darkMode)

        switch newMode {
        case .system:
            isDarkMode = Self.currentSystemIsDark
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        }
    }

    /// システムの外観変更の監視を開始する
    func startObservingSystemAppearance() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemAppearanceChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - プライベートメソッド

    /// 現在のシステムがダークモードかどうかを取得
    private static var currentSystemIsDark: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return false
        }
        return window.traitCollection.userInterfaceStyle == .dark
    }

    @objc private func handleSystemAppearanceChange() {
        guard mode == .system else { return }
        let newDarkMode = Self.currentSystemIsDark
        if isDarkMode != newDarkMode {
            isDarkMode = newDarkMode
        }
    }
}
