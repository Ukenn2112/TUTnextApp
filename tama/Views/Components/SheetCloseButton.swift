import SwiftUI

/// シートのツールバーに置く「閉じる」ボタン。
///
/// 文字とシンボルの両方を持つ標準のボタンにしておき、ツールバーではシンボルだけが表示される
/// （VoiceOverは「閉じる」と読み上げる）。iOS 26以降は閉じるロールを付けて、
/// システム標準の閉じるボタンの見た目・振る舞いにする。
///
/// 使い方:
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .topBarLeading) {
///         SheetCloseButton { dismiss() }
///     }
/// }
/// ```
struct SheetCloseButton: View {

    /// 押されたときの処理（通常は `dismiss()`）
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button("閉じる", systemImage: "xmark", role: .close, action: action)
            } else {
                Button("閉じる", systemImage: "xmark", action: action)
            }
        }
        // 共通ツールバーの項目と同じく、アプリのアクセントカラー（タブバーから継承される）ではなく黒で描く
        .toolbarItemTint()
    }
}
