import SwiftUI

// MARK: - 折り目（分割の予約領域）

/// 本のように折ったときに画面を左右へ分ける帯（`ReservedRegion` の `.division`）を、
/// ページのローカル座標で表した値。
///
/// 予約領域は折り方によらず常に報告され、折りたたんだときだけ `isActive` が真になる。
/// 「領域が有るかどうか」ではなく **必ず `isActive` で分岐する**（`docs/iphone-duo-metrics.md` §8.1）。
/// 起動直後の2〜3回のレイアウトでは空で返るため、その間は `nil` として扱えばよい。
///
/// 帯そのものの幅だけでなく、左右に20ptずつ付く `margins` も避けるべき範囲に含める。
/// 押せる要素はこの範囲（`start`〜`end`）に入れない
struct DuoDivision: Equatable {

    /// 避けるべき範囲の始まり（ページのローカル座標）
    let start: CGFloat

    /// 避けるべき範囲の終わり
    let end: CGFloat

    /// 帯の幅（余白込み）
    var width: CGFloat { max(0, end - start) }

    /// いま有効な縦の折り目（＝本のポーズ）を読む。無効・非対応・まだ報告されていないときは nil。
    ///
    /// 横向きの折り目（テーブルトップ）は上下に分けるものなので、ここでは対象にしない
    static func verticalFold(in proxy: GeometryProxy) -> DuoDivision? {
        guard #available(iOS 27.1, *) else { return nil }

        // `.mirrors`（既定値）では枠も余白も書字方向に合わせて反転した座標で返るため、
        // RTLでも minX 側が常に `leading`、maxX 側が `trailing` になる。
        // 呼び出し側（`DuoColumnSplit`）も先頭側の列から幅を数えるので、この組み合わせのまま使う
        let regions = proxy.reservedRegions(
            kind: .division, options: .includeInactive, layoutDirectionBehavior: .mirrors)
        guard let region = regions.first(where: {
            $0.isActive && $0.frame.height > $0.frame.width
        }) else {
            return nil
        }

        return DuoDivision(
            start: region.frame.minX - region.margins.leading,
            end: region.frame.maxX + region.margins.trailing
        )
    }
}

// MARK: - 折り目で分けた2つの列

/// 折り目が有効なときの、左右2つの列の幅と、その間（折り目の帯＋余白）。
///
/// 左の列はヒンジの手前まで、右の列はヒンジの向こう側から。
/// 押せるものをこの列の中だけに置けば、折り目に掛かることはない。
/// 折り目が無効（平らなとき）・非対応・まだ報告されていないときは nil を返し、
/// 呼び出し側は等幅の2列にする
struct DuoColumnSplit: Equatable {

    let leadingWidth: CGFloat
    let gutter: CGFloat
    let trailingWidth: CGFloat

    /// - Parameters:
    ///   - proxy: スクロールしない入れ物のプロキシ（ページと同じ横の座標を持つもの）
    ///   - padding: ページが内容に付けている横の余白
    static func make(proxy: GeometryProxy, padding: CGFloat) -> DuoColumnSplit? {
        guard let fold = DuoDivision.verticalFold(in: proxy) else { return nil }
        let leading = fold.start - padding
        let trailing = proxy.size.width - fold.end - padding
        guard leading > 0, trailing > 0 else { return nil }
        return DuoColumnSplit(
            leadingWidth: leading, gutter: fold.width, trailingWidth: trailing)
    }
}
