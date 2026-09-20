import SwiftUI

// MARK: - ページタイトルの体裁

/// ページタイトルの体裁（全ポーズ・全端末で共通）。
///
/// 横バーのポーズではナビゲーションバーの先頭に置くツールバー項目として、
/// 縦バーのポーズでは `VerticalBarPageTitle` としてページ内容の先頭に描くが、
/// 文字サイズ・太さ・寄せはどちらも同じにする
enum PageTitleStyle {

    /// タイトルの文字サイズ（ポーズや端末によらず同じ値を使う）
    static let fontSize: CGFloat = 24

    /// タイトルのフォント
    static var font: Font { .system(size: fontSize, weight: .semibold) }

    /// ページ内に描くときの先頭の余白。
    /// システムのナビゲーションバーがタイトルに使う標準の先頭マージンに合わせる
    static let leadingMargin: CGFloat = 20

    /// 長いローカライズ名（英語の学期名など）でも1行に収めるための最小縮小率
    static let minimumScaleFactor: CGFloat = 0.6
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
    var glyphTopMargin: CGFloat = VerticalBarLayout.edgeMargin

    // MARK: - ボディ

    var body: some View {
        Text(title)
            .font(PageTitleStyle.font)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(PageTitleStyle.minimumScaleFactor)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, PageTitleStyle.leadingMargin)
            // Text の枠上端はグリフ上端より上にあるので、その分を戻してグリフ上端を合わせる
            .padding(.top, glyphTopMargin - Self.glyphTopInset)
    }
}

// MARK: - タイポグラフィの寸法

extension VerticalBarPageTitle {

    /// `Text` の枠の高さ（＝フォントの行の高さ）
    static var lineHeight: CGFloat {
        UIFont.systemFont(ofSize: PageTitleStyle.fontSize, weight: .semibold).lineHeight
    }

    /// `Text` の枠上端からグリフ上端までの距離。
    /// 和文（漢字・数字）は ascender いっぱいまでは描かれないため、その差を文字サイズ比で持つ
    /// （SFの和文フォールバックで実測。文字サイズを変えても比は変わらない）
    static var glyphTopInset: CGFloat { PageTitleStyle.fontSize * 0.1838 }

    /// `Text` の枠下端からグリフ下端までの距離（descender のうち描かれない分）
    static var glyphBottomInset: CGFloat { PageTitleStyle.fontSize * 0.1343 }
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
                // iOS 17には該当APIが無い（従来どおりの中央インラインタイトルになる）
                self
            }
        } else {
            self
        }
    }
}
