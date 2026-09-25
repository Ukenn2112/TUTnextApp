import SwiftUI

// MARK: - 共通のトランジション

/// ビューの出入りに使うトランジションの種類。
///
/// 「視差効果を減らす」が有効なときは、どれを選んでも単純なフェード（`.opacity`）になる。
/// トランジション自体の速さは、状態を変えるときの `withMotion(_:_:)` /
/// `motionAnimation(_:value:)` で決める
enum MotionTransition {
    /// 単純なフェード
    case fade
    /// フェードしながら 8pt 下から持ち上がる（リストの行・カードの登場）
    case rise
    /// ぼかしながら入れ替わる（同じ場所で内容が差し替わるとき）
    case swap
    /// 指定した辺から滑り込み、フェードする
    case slide(Edge)

    /// 持ち上がる距離（pt）
    static let riseOffset: CGFloat = 8

    /// 通常時のトランジション
    var transition: AnyTransition {
        switch self {
        case .fade:
            return .opacity
        case .rise:
            return .opacity.combined(with: .offset(y: Self.riseOffset))
        case .swap:
            return AnyTransition(.blurReplace)
        case .slide(let edge):
            return .move(edge: edge).combined(with: .opacity)
        }
    }

    /// 「視差効果を減らす」の設定を反映したトランジション
    func resolved(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }
}

extension View {

    /// 共通のトランジションを付ける。「視差効果を減らす」が有効ならフェードだけになる。
    ///
    /// ```swift
    /// if isShown {
    ///     Banner().motionTransition(.rise)
    /// }
    /// // 状態は withMotion(Motion.standard) { isShown = true } で変える
    /// ```
    func motionTransition(_ kind: MotionTransition) -> some View {
        modifier(MotionTransitionModifier(kind: kind))
    }
}

/// `motionTransition(_:)` の本体。環境から「視差効果を減らす」を読むために修飾子にしている
private struct MotionTransitionModifier: ViewModifier {
    let kind: MotionTransition

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(kind.resolved(reduceMotion: reduceMotion))
    }
}
