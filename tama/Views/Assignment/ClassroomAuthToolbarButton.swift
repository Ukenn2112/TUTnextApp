import SwiftUI

// MARK: - Classroom認証のツールバー項目

/// 課題タブのツールバーに置く Google Classroom の認証ボタン。
///
/// 縦バーに入るのはシンボルとタイトルの両方を持つ項目だけなので、認証中も `ProgressView` に
/// 差し替えず、シンボルのまま `symbolEffect` で処理中であることを示す。
///
/// シンボルは設定ボタン（`person.crop.circle`）と見分けが付くよう、人物ではなく
/// 教材を表す `books.vertical` を使う。
///
/// 動作は従来の `HeaderView` のボタンと同じ:
/// - 未認証 … OAuthフローを開始する
/// - 認証済み … 取り消し確認（アラートの表示は呼び出し側が持つ）
/// - 認証中 … 押せない
struct ClassroomAuthToolbarButton: View {

    // MARK: - プロパティ

    @EnvironmentObject private var oauthService: GoogleOAuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 認証取り消しの確認アラートを出すかどうか（アラート自体は呼び出し側にある）
    @Binding var showRevokeConfirmation: Bool

    /// 認証処理中（WebViewを出す前の準備中）かどうか
    private var isPreparing: Bool {
        oauthService.isAuthorizing && !oauthService.showOAuthWebView
    }

    // MARK: - ボディ

    var body: some View {
        Button {
            if oauthService.isAuthorized {
                showRevokeConfirmation = true
            } else {
                oauthService.startOAuth()
            }
        } label: {
            label
        }
        .tint(oauthService.isAuthorized ? .green : .primary)
        .disabled(isPreparing)
    }

    /// 状態ごとのシンボルとタイトル
    @ViewBuilder private var label: some View {
        if oauthService.showOAuthWebView || isPreparing {
            // 認証中もシンボルを保ったまま、点滅で処理中であることを伝える
            Label(
                NSLocalizedString("認証中", comment: "認証中ステータス"),
                systemImage: "books.vertical"
            )
            // 「視差効果を減らす」が有効なら点滅させず、シンボルと文言だけで伝える
            .symbolEffect(.pulse, isActive: !reduceMotion)
        } else if oauthService.isAuthorized {
            Label(
                NSLocalizedString("認証済み", comment: "認証済みステータス"),
                systemImage: "checkmark.circle.fill"
            )
        } else {
            Label(
                NSLocalizedString("Classroom 認証", comment: "Classroom認証ボタン"),
                systemImage: "books.vertical"
            )
        }
    }
}
