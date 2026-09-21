import SwiftUI

// MARK: - 2列にするかの判定

/// ページを左右2つの列に分けるかどうかの判定（iPhone Duoの内側ディスプレイ・横向きだけ）。
///
/// 時間割タブ（`TimetableView.isTwoPane`）と同じ条件をバスタブ・課題タブでも使うため、
/// 条件そのものはここ一箇所に置く:
///
/// - Duoの新しいAPIが使える（iOS 27.1以降）
/// - 幅がレギュラー
/// - ページが縦より横に長い
///
/// 内側の縦向き・外側ディスプレイ・Split View・通常のiPhoneはどれかの条件で外れるので、
/// 従来どおり1列のままになる。
/// `ArrangementView` の内部状態は読めないため、判定は各ページが自分の大きさから行う
enum DuoTwoPane {

    /// このページを2列にするか
    /// - Parameters:
    ///   - containerSize: セーフエリアを無視したあとのページの実寸
    ///   - horizontalSizeClass: そのページの位置で読んだ横のサイズクラス
    static func isEnabled(
        containerSize: CGSize, horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        guard horizontalSizeClass == .regular else { return false }
        return containerSize.height > 0 && containerSize.width > containerSize.height
    }
}
