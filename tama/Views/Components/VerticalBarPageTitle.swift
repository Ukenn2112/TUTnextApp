import SwiftUI

// MARK: - ページタイトルの体裁

/// ページタイトルの体裁（全ポーズ・全端末で共通）。
///
/// 横バーのポーズではナビゲーションバーの先頭に置くツールバー項目として、
/// 縦バーのポーズでは `VerticalBarPageTitle` としてページ内容の先頭に描くが、
/// 文字サイズ・太さ・寄せはどちらも同じにする
enum PageTitleStyle {

    /// 既定の文字サイズ（Dynamic Typeが標準の「大」のときの値。ポーズや端末によらず同じ値を使う）
    static let baseFontSize: CGFloat = 24

    /// 文字サイズを拡大・縮小するときに追従するテキストスタイル。
    /// ビューでは `@ScaledMetric(relativeTo: textStyle)` で `baseFontSize` を拡縮して使う
    static let textStyle: Font.TextStyle = .title2

    /// レイアウト計算用の、現在のDynamic Typeで拡縮した文字サイズ。
    /// ビュー側の `@ScaledMetric(relativeTo: textStyle)` と同じ拡縮になるよう、同じテキストスタイルで計算する
    static var fontSize: CGFloat {
        UIFontMetrics(forTextStyle: .title2).scaledValue(for: baseFontSize)
    }

    /// タイトルのフォント（`size` には拡縮済みの文字サイズを渡す）
    static func font(size: CGFloat) -> Font { .system(size: size, weight: .semibold) }

    /// 長いローカライズ名（英語の学期名など）でも1行に収めるための最小縮小率
    static let minimumScaleFactor: CGFloat = 0.6

    /// `Text` の枠上端からグリフ上端までの距離の、文字サイズに対する比。
    /// 和文（漢字・数字）は ascender いっぱいまでは描かれないため、その差を比で持つ。
    /// SFの和文フォールバックで実測した書体の性質で、Duoの寸法ではない
    /// （フォールバック書体のグリフの外接矩形を得る公開APIが無いため、比として持つ。文字サイズを変えても比は変わらない）
    static let glyphTopInsetRatio: CGFloat = 0.1838

    /// `Text` の枠下端からグリフ下端までの距離（descender のうち描かれない分）の、文字サイズに対する比
    static let glyphBottomInsetRatio: CGFloat = 0.1343
}

// MARK: - タイトルを寄せる辺

/// ページタイトルをどちらの辺に寄せるか。
///
/// 既定は先頭寄せ（左から書く言語では左）。2ペイン表示の右ペインのように、
/// 末尾側の辺に揃えたい場合だけ `.trailing` を使う。
/// `leading` / `trailing` はどちらも書字方向に追従するので、RTLでも自動的に反転する
enum PageTitleEdge {

    case leading
    case trailing

    /// 枠の中での寄せ
    var alignment: Alignment { self == .leading ? .leading : .trailing }

    /// 余白を入れる辺
    var edge: Edge.Set { self == .leading ? .leading : .trailing }

    /// 折り返したときの行の寄せ
    var textAlignment: TextAlignment { self == .leading ? .leading : .trailing }
}

// MARK: - ページ内タイトル

/// 縦バーのポーズで、ページ内容の先頭に自前で描くページタイトル。
///
/// 縦バーのポーズではシステムのナビゲーションタイトルは82ptのバー帯の中に固定され、位置を変えられない。
/// そのため帯の中のタイトルは消し（`hidingSystemNavigationTitle(_:)`）、同じ見た目のタイトルを
/// ページの内容としてここで描く。こうするとタイトルの上端をウィンドウ上端から
/// `VerticalBarLayout.edgeMargin` の位置に置けるので、下端のマージンと対称になる。
///
/// 使い方（時間割タブ・バスタブなど、縦バーのポーズで上を詰めたいページ共通）:
/// ```swift
/// VStack(spacing: 0) {
///     if isVerticalBarPose {
///         VerticalBarPageTitle(title: semester.fullDisplayName)
///     }
///     content
/// }
/// ```
struct VerticalBarPageTitle: View {

    // MARK: - プロパティ

    /// 表示する文字列（システムのナビゲーションタイトルと同じ値を渡す）
    let title: String

    /// ウィンドウ上端からグリフ（文字の描画範囲）の上端までの距離
    let glyphTopMargin: CGFloat

    /// 寄せる辺（既定は先頭寄せ）
    let edge: PageTitleEdge

    /// 寄せた辺に取る余白。
    /// nil（既定）のときはシステムの最小のシーン余白（`scenePadding(.minimum)`）に任せ、
    /// ナビゲーションバーの項目と同じくシステムのマージンに揃える
    let sideMargin: CGFloat?

    /// タイトルの文字サイズ（Dynamic Typeに追従する）
    @ScaledMetric(relativeTo: PageTitleStyle.textStyle) private var fontSize = PageTitleStyle.baseFontSize

    // MARK: - 初期化

    /// 非公開の `fontSize` があるとメンバーごとのイニシャライザが非公開になるため、明示的に定義する
    init(
        title: String,
        glyphTopMargin: CGFloat = VerticalBarLayout.edgeMargin,
        edge: PageTitleEdge = .leading,
        sideMargin: CGFloat? = nil
    ) {
        self.title = title
        self.glyphTopMargin = glyphTopMargin
        self.edge = edge
        self.sideMargin = sideMargin
    }

    // MARK: - ボディ

    var body: some View {
        Text(title)
            .font(PageTitleStyle.font(size: fontSize))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(PageTitleStyle.minimumScaleFactor)
            .multilineTextAlignment(edge.textAlignment)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: edge.alignment)
            .pageTitleSideMargin(sideMargin, edges: edge.edge)
            // Text の枠上端はグリフ上端より上にあるので、その分を戻してグリフ上端を合わせる
            .padding(.top, glyphTopMargin - fontSize * PageTitleStyle.glyphTopInsetRatio)
    }
}

private extension View {

    /// タイトルの横の余白。値が無ければシステムの最小のシーン余白を使う
    @ViewBuilder func pageTitleSideMargin(_ margin: CGFloat?, edges: Edge.Set) -> some View {
        if let margin {
            padding(edges, margin)
        } else {
            scenePadding(.minimum, edges: edges)
        }
    }
}

// MARK: - タイポグラフィの寸法

extension VerticalBarPageTitle {

    // レイアウト計算用の値。どれも現在のDynamic Typeで拡縮した文字サイズ（`PageTitleStyle.fontSize`）から求める

    /// `Text` の枠の高さ（＝フォントの行の高さ）
    static var lineHeight: CGFloat {
        UIFont.systemFont(ofSize: PageTitleStyle.fontSize, weight: .semibold).lineHeight
    }

    /// `Text` の枠上端からグリフ上端までの距離
    static var glyphTopInset: CGFloat { PageTitleStyle.fontSize * PageTitleStyle.glyphTopInsetRatio }

    /// `Text` の枠下端からグリフ下端までの距離（descender のうち描かれない分）
    static var glyphBottomInset: CGFloat { PageTitleStyle.fontSize * PageTitleStyle.glyphBottomInsetRatio }
}

// MARK: - システムタイトルの非表示

extension View {

    /// ナビゲーションバーの帯からタイトルだけを取り除く。
    ///
    /// `NavigationStack` とツールバー項目（掲示情報・設定）はそのまま残るので、
    /// 項目は引き続き縦バーに並ぶ。ページのタイトルは横バーのポーズでは先頭のツールバー項目が、
    /// 縦バーのポーズでは `VerticalBarPageTitle` が内容として描く
    @ViewBuilder func hidingSystemNavigationTitle(_ isHidden: Bool) -> some View {
        if isHidden {
            if #available(iOS 18.0, *) {
                toolbar(removing: .title)
            } else {
                // iOS 17には該当APIが無い（従来どおりの中央インラインタイトルになる）。
                // そのため `mainToolbar` もiOS 17では先頭のタイトル項目を作らず、タイトルが二重に出ないようにしている
                self
            }
        } else {
            self
        }
    }
}
