import SwiftUI

// MARK: - 読みやすい幅

/// コンテンツを読みやすい幅に収めるための上限値。
/// 特定の端末の寸法ではなく、1行が長くなりすぎないための可読性の目安として定義している
enum ReadableWidth {
    /// 入力欄が中心の画面（ログインフォームなど）
    static let form: CGFloat = 420

    /// 一般的なスクロール・フォーム系の画面
    static let page: CGFloat = 560
}

extension View {
    /// コンテンツを読みやすい幅に収めて中央に寄せる。
    ///
    /// コンパクト幅のiPhoneでは上限に届かないため、見た目は変わらない。
    /// 幅の広いウィンドウ（iPhone Duoの内側ディスプレイ、Split View等）でのみ効果がある
    func readableWidth(_ maxWidth: CGFloat = ReadableWidth.page) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
