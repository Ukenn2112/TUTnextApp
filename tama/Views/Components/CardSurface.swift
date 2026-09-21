import SwiftUI

// MARK: - カードの体裁

/// 科目詳細・課題カード・バスの時刻カードで共通に使っているカードの見た目。
///
/// 角丸・縁取りは元々それぞれの画面に直接書かれていたが、
/// 時間割タブの「今日」ペインでも同じ見た目が要るので、ここへまとめて共有する。
///
/// **アプリ全体の決まり**: ページの地はどの画面も `pageFill`（＝白／ダークでは黒）で、
/// その上に置くカードは `outlinedCard()`（同じ地の色＋1ptの枠）1種類だけを使う。
/// 影で浮かせるカードは作らない（画面ごとにカードの言葉が変わって見えるため）。
/// 灰色の地に白いカードを浮かせる組み方も、画面ごとに地の色が変わって見えるため使わない
enum CardSurface {

    /// 角丸の半径
    static let cornerRadius: CGFloat = 12

    /// 内容とカードの縁の間の余白
    static let padding: CGFloat = 16

    /// ページの地の色。どの画面もこれ1つだけを使う（明るい外観では白、暗い外観では黒）
    static var pageFill: Color { Color(UIColor.systemBackground) }

    /// カードの塗り。地の色と同じで、輪郭は枠で取る
    static var raisedFill: Color { pageFill }

    /// 内側の入力欄・区画など、カードの中だけで使う一段沈んだ塗り。
    /// ページの地には使わない
    static var inlineFill: Color { Color(UIColor.secondarySystemBackground) }

    /// 白い地のページに置くカードの枠。
    /// 時間割の時限セル（`TimeSlotCell`）と同じ「1ptの薄いグレーの角丸」に揃える
    static var outlineStroke: Color { Color(UIColor.separator) }
    static let outlineWidth: CGFloat = 1
}

extension View {

    /// 内容をアプリ共通のカード（白い地・1ptの枠・共通の角丸）で包む。
    ///
    /// ページの地もカードの塗りも `CardSurface.pageFill` なので、
    /// カードの輪郭は影ではなく枠で取る。どの画面のカードもこれ1つだけを使う
    /// - Parameters:
    ///   - padding: 内容の余白（既定はカード共通の16）
    ///   - cornerRadius: 角丸の半径（既定はカード共通の12）
    func outlinedCard(
        padding: CGFloat = CardSurface.padding,
        cornerRadius: CGFloat = CardSurface.cornerRadius
    ) -> some View {
        cardSurface(
            fill: CardSurface.pageFill, padding: padding, outlined: true,
            cornerRadius: cornerRadius)
    }

    /// 内容をカードの体裁（余白・角丸・背景・枠）で包む
    /// - Parameters:
    ///   - fill: カードの塗り。ページの地の色に合わせて `CardSurface.raisedFill` か `inlineFill` を渡す
    ///   - padding: 内容の余白（既定はカード共通の16）
    ///   - outlined: 1ptの細い枠で輪郭を取るかどうか。
    ///     ページの上に置くカードは必ず `true`（＝`outlinedCard()`）。
    ///     `false` はカードの中の区画など、輪郭を取らずに塗りだけを敷きたいときに使う
    ///   - cornerRadius: 角丸の半径（既定はカード共通の12。左ペインの時限セルと
    ///     並べるカードだけ、セルと同じ半径を渡して見た目を揃える）
    func cardSurface(
        fill: Color, padding: CGFloat = CardSurface.padding, outlined: Bool = true,
        cornerRadius: CGFloat = CardSurface.cornerRadius
    ) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .overlay {
                        if outlined {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    CardSurface.outlineStroke,
                                    lineWidth: CardSurface.outlineWidth)
                        }
                    }
            }
    }
}
