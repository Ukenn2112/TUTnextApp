import SwiftUI
import UIKit

/// アプリの外観（ダークモード等）を管理するクラス
///
/// UIWindowの `overrideUserInterfaceStyle` を使用して外観を切り替える。
/// この方式はSheet・Alert・ActionSheet等すべてのUIに確実に適用される。
/// 適用そのものは `appearanceOverride(_:)` を付けたビューが自身のウィンドウに対して行うため、
/// このクラスはシーンやウィンドウを直接参照しない。
final class AppearanceManager: ObservableObject {

    // MARK: - 列挙型

    /// 外観モードの種類
    enum AppearanceMode: Int {
        case system = 0
        case light = 1
        case dark = 2

        /// ウィンドウに設定するUIKit側のスタイル
        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: return .unspecified
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // MARK: - プロパティ

    @Published var mode: AppearanceMode

    // MARK: - 初期化

    init() {
        self.mode = AppearanceMode(rawValue: AppDefaults.darkMode) ?? .system
    }

    // MARK: - 公開メソッド

    /// 外観モードを変更する
    func setMode(_ newMode: AppearanceMode) {
        mode = newMode
        AppDefaults.darkMode = newMode.rawValue
    }
}

// MARK: - ウィンドウへの適用

extension View {
    /// 選択中の外観モードを、このビューが属するウィンドウに適用する。
    /// ルートビューに付けることで、そのウィンドウ上に表示されるSheet・Alert等にも反映される
    func appearanceOverride(_ manager: AppearanceManager) -> some View {
        background(
            AppearanceOverrideView(style: manager.mode.interfaceStyle)
                .frame(width: 0, height: 0)
        )
    }
}

/// 自身のウィンドウに `overrideUserInterfaceStyle` を設定するだけの、レイアウトに影響しないビュー
private struct AppearanceOverrideView: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> StyleApplyingView {
        StyleApplyingView(style: style)
    }

    func updateUIView(_ uiView: StyleApplyingView, context: Context) {
        uiView.style = style
    }

    /// ウィンドウに追加された時点と、モードが変わった時点の両方でスタイルを適用する
    final class StyleApplyingView: UIView {
        var style: UIUserInterfaceStyle {
            didSet { applyStyle() }
        }

        init(style: UIUserInterfaceStyle) {
            self.style = style
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyStyle()
        }

        private func applyStyle() {
            guard let window, window.overrideUserInterfaceStyle != style else { return }
            window.overrideUserInterfaceStyle = style
        }
    }
}
