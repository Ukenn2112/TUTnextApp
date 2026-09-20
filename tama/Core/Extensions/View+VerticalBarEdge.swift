import SwiftUI

// MARK: - 縦バーのポーズの寸法

/// 縦バーのポーズ（iPhone Duoの外側ディスプレイ・内側横向き・Split View）で共通に使う寸法
enum VerticalBarLayout {

    /// システムの縦バーが上端・下端に残すマージン。
    /// バー内のコントロールのフレームはAPIで公開されていないため、同じ値を定数として持つ。
    /// 上下どちらの端にも同じ値を使い、ページ内容の上端・下端をバーの端のコントロールと揃える
    /// （mirrors the system vertical bar's 24pt edge margin; bar controls' frames are not exposed）
    static let edgeMargin: CGFloat = 24
}

// MARK: - 縦バーのポーズ

/// システムがツールバー（ナビゲーションバー・タブバー）を縦バーとして表示しているかどうかを親へ伝える。
///
/// iPhone Duoの外側ディスプレイ・内側横向き・Split Viewでは、バーが画面の端に縦に並ぶ。
/// その判定は `\.toolbarVerticalEdge`（iOS 27.1以降）で行うが、
/// `@available` を付けた `@Environment` はiOS 17を最低対象とする型には置けないため、
/// 読み取り専用の不可視ビューを挟んで値を渡す（`DuoMetricsOverlay` と同じ方式）。
///
/// 起動直後の2〜3回のレイアウトでは値が nil で、横バーのポーズでも nil が正しい値になる。
/// そのため「縦バーではない」を初期値として扱い、非nilになった時点で切り替える
extension View {

    /// 縦バーのポーズかどうかが変わったときに `action` を呼ぶ。
    /// レイアウトにもヒットテストにも影響しない
    func onVerticalBarEdgeChange(_ action: @escaping (Bool) -> Void) -> some View {
        background { VerticalBarEdgeReader(action: action) }
    }
}

/// iOS 27.1以降でのみ実際の読み取りビューを挿す入れ物
private struct VerticalBarEdgeReader: View {

    let action: (Bool) -> Void

    var body: some View {
        if #available(iOS 27.1, *) {
            VerticalBarEdgeProbe(action: action)
        }
    }
}

/// `toolbarVerticalEdge` を監視して、縦バーかどうかだけを通知する不可視ビュー
@available(iOS 27.1, *)
private struct VerticalBarEdgeProbe: View {

    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    let action: (Bool) -> Void

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: toolbarVerticalEdge != nil, initial: true) { _, isVerticalBar in
                action(isVerticalBar)
            }
    }
}
