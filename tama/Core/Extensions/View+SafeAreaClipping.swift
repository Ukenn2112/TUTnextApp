import SwiftUI

// MARK: - 横方向のセーフエリアでの切り取り

extension View {
    /// 横スクロールする行を、ページ内容の列の内側だけに描く。
    ///
    /// 縦バーのポーズ（iPhone Duoの外側ディスプレイ・内側横向き・Split View）では、
    /// タブバー・ツールバーの項目・時計・カメラが画面の端に縦に並び、
    /// その帯はページ内容の左右どちらかのセーフエリアになる（Split Viewでは左端になることもある）。
    /// `ScrollView` はスクロール軸方向のセーフエリアを自動的に無視して内容をその下まで描くため、
    /// 何もしないとカードやチップが縦バーの裏に透けて見える。
    ///
    /// セーフエリアを無視しない入れ物にスクロールビューを入れ、その枠で切り取る。
    /// さらに、セーフエリアの余白が0より大きい辺（＝縦バーなどが占めている側）では、
    /// 入れ物をページの横余白 `contentInset` の分だけ内側に寄せ、
    /// 切り取り線を下の時刻表・セグメント・カードの端とぴったり揃える。
    /// 余白が0の辺（通常のiPhoneの縦向き、縦バーの無い側）では何も引かないため、
    /// 行は従来どおり画面の端から端まで描かれ、見た目は変わらない。
    ///
    /// 入れ物そのものを狭めるので、スクロールの見える範囲が切り取り線で終わる。
    /// 先頭の項目の位置は変わらず、末尾の項目も内容側の余白を保ったまま最後まで見える。
    ///
    /// - Parameter contentInset: そのページが内容の列に付けている横の余白
    func clippedToHorizontalSafeArea(contentInset: CGFloat) -> some View {
        modifier(HorizontalSafeAreaClip(contentInset: contentInset))
    }
}

// MARK: - 切り取りの実装

/// セーフエリアの内側、かつページ内容の列の内側で横スクロールの行を切り取る
private struct HorizontalSafeAreaClip: ViewModifier {
    let contentInset: CGFloat

    /// 縦バーなどが占めている辺だけに入れる余白（占めていない辺は0）
    @State private var leadingInset: CGFloat = 0
    @State private var trailingInset: CGFloat = 0

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
        }
        .clipped()
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        // セーフエリアの余白はポーズによって左右どちらにも付くため、その場で読む。
        // ここはスクロールビューの外側なので、横方向の余白がそのまま見える
        .onGeometryChange(for: HorizontalInsets.self) { proxy in
            HorizontalInsets(
                leading: proxy.safeAreaInsets.leading,
                trailing: proxy.safeAreaInsets.trailing
            )
        } action: { insets in
            leadingInset = insets.leading > 0 ? contentInset : 0
            trailingInset = insets.trailing > 0 ? contentInset : 0
        }
    }

    /// 左右のセーフエリアの余白だけを取り出した値
    private struct HorizontalInsets: Equatable {
        let leading: CGFloat
        let trailing: CGFloat
    }
}
