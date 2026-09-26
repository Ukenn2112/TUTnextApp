import SwiftUI
import UIKit

// MARK: - モーションの基準値

/// アプリ全体で共有するアニメーションの基準値（モーショントークン）。
///
/// **方針**: 落ち着いた「リニア寄り」の動き。アプリ内で跳ねる（bounce する）ものは一つもなく、
/// すべて `smooth` 系（bounce 0）で揃える。
/// 取得したデータの到着・再読み込みでは動かさず、利用者の操作による変化だけを動かす。
///
/// **視差効果を減らす（Reduce Motion）**: どのアニメーションも直接 `.animation(_:value:)` /
/// `withAnimation` に渡さず、`motionAnimation(_:value:)` / `withMotion(_:_:)` を通すこと。
/// 有効なときは自動的に `reduced`（短いクロスフェード）へ差し替わる
enum Motion {

    /// 選択・チップ・ハイライト・バッジなど、小さな状態の切り替え
    static let quick = Animation.smooth(duration: 0.20)

    /// 内容の差し替え・絞り込み結果・ペインの入れ替え
    static let standard = Animation.smooth(duration: 0.32)

    /// 少し長めに見せたい変化。跳ねない（bounce 0）。
    /// アプリ内に跳ねるアニメーションはないため、`standard` より少しゆっくりなだけ
    static let emphasized = Animation.smooth(duration: 0.4)

    /// 「視差効果を減らす」が有効なときの代わりの動き（短いクロスフェード）
    static let reduced = Animation.easeInOut(duration: 0.18)

    /// スケルトンのきらめきが1往復ではなく左から右へ1回流れる時間（秒）
    static let shimmerPeriod: Double = 1.5

    /// スケルトンのきらめき（左から右へ一定速度で繰り返す）
    static let shimmer = Animation.linear(duration: shimmerPeriod).repeatForever(autoreverses: false)

    /// 読み込みが始まってからスケルトンを出すまでの猶予。
    /// キャッシュからすぐに表示できる場合にスケルトンが一瞬ちらつかないようにする
    static let skeletonDelay: Duration = .milliseconds(180)

    /// 「視差効果を減らす」の設定を反映したアニメーションを返す
    /// - Parameters:
    ///   - animation: 通常時に使うアニメーション
    ///   - reduceMotion: `\.accessibilityReduceMotion` の値
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}

// MARK: - 値の変化に合わせたアニメーション

extension View {

    /// `value` が変わったときに `animation` で動かす。
    /// 「視差効果を減らす」が有効なら `Motion.reduced`（短いクロスフェード）に差し替える。
    ///
    /// `.animation(_:value:)` の代わりに使う
    func motionAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionAnimationModifier(animation: animation, value: value))
    }
}

/// `motionAnimation(_:value:)` の本体。環境から「視差効果を減らす」を読むために修飾子にしている
private struct MotionAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Motion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

// MARK: - 状態の変更に合わせたアニメーション

/// `withAnimation` の代わりに使う。
/// 「視差効果を減らす」が有効なら `Motion.reduced`（短いクロスフェード）で動かす。
///
/// ビューの外（ViewModel の完了処理など）からも呼べるよう、環境ではなく
/// `UIAccessibility.isReduceMotionEnabled` を見る
@MainActor
@discardableResult
func withMotion<Result>(_ animation: Animation = Motion.standard, _ body: () throws -> Result) rethrows -> Result {
    let resolved = Motion.resolved(animation, reduceMotion: UIAccessibility.isReduceMotionEnabled)
    return try withAnimation(resolved, body)
}
