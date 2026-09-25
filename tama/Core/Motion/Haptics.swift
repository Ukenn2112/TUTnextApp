import SwiftUI

// MARK: - 触覚フィードバック

/// 触覚フィードバックの使い分け（iOS 17 の `.sensoryFeedback` を使う）。
///
/// - **選択** (`selectionHaptic`): チップ・セグメント・路線など、並びの中から1つを選び直したとき。
///   同じものをもう一度押しただけのときは鳴らさない
/// - **エラー** (`errorHaptic`): ログイン失敗など、利用者の操作が受け付けられなかったとき。
///   ネットワークの自動更新の失敗など、利用者が操作していない失敗では鳴らさない
///
/// 成功・通知などの種類はむやみに増やさず、まずこの2つだけを使う
extension View {

    /// `trigger` が変わったときに「選択」の触覚を返す
    func selectionHaptic<T: Equatable>(trigger: T) -> some View {
        sensoryFeedback(.selection, trigger: trigger)
    }

    /// `trigger` が変わったときに「エラー」の触覚を返す。
    /// 失敗のたびに鳴らしたいときは、回数などの増え続ける値を `trigger` に渡す
    func errorHaptic<T: Equatable>(trigger: T) -> some View {
        sensoryFeedback(.error, trigger: trigger)
    }
}

// MARK: - 揺れ（入力エラー）

extension View {

    /// `trigger` が変わるたびに左右へ小さく揺らす（±6pt を3往復・0.35秒）。
    /// ログイン失敗などで入力欄を揺らすのに使う。「視差効果を減らす」が有効なら揺らさない。
    ///
    /// ```swift
    /// @State private var failureCount = 0
    /// form
    ///     .shake(trigger: failureCount)
    ///     .errorHaptic(trigger: failureCount)
    /// ```
    func shake<T: Equatable>(trigger: T) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

private struct ShakeModifier<T: Equatable>: ViewModifier {
    let trigger: T

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 揺れ幅（pt）
    private static var amplitude: CGFloat { 6 }

    /// 揺れ全体の長さ（秒）
    private static var totalDuration: Double { 0.35 }

    func body(content: Content) -> some View {
        // 揺れ幅に掛ける係数。描画用のクロージャは Sendable なので、値として先に取り出しておく
        let scale: CGFloat = reduceMotion ? 0 : 1
        return content
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
                view.offset(x: offset * scale)
            } keyframes: { _ in
                // -6, +6 を3往復して 0 に戻る（7区間）
                let step = Self.totalDuration / 7
                KeyframeTrack {
                    CubicKeyframe(-Self.amplitude, duration: step)
                    CubicKeyframe(Self.amplitude, duration: step)
                    CubicKeyframe(-Self.amplitude, duration: step)
                    CubicKeyframe(Self.amplitude, duration: step)
                    CubicKeyframe(-Self.amplitude, duration: step)
                    CubicKeyframe(Self.amplitude, duration: step)
                    CubicKeyframe(0, duration: step)
                }
            }
    }
}
