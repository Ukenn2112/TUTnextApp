import SwiftUI

/// 各タブ共通のシステムツールバー（ページタイトル・掲示情報・設定）。
///
/// `HeaderView` が持っていた独自ヘッダーの代わりに、`NavigationStack` のツールバーへ項目を置く。
/// iPhone Duo では外側ディスプレイ・内側横向きでツールバーが縦バーへ移るが、
/// 縦バーに入るのはシンボルとタイトルの両方を持つ項目だけなので、必ず `Label` で定義する。
///
/// タイトルはポーズによって描き方が変わる（大きさ・寄せは `PageTitleStyle` で共通）:
/// - 横バーのポーズ … バーの先頭（`.topBarLeading`）に置くツールバー項目として描く
/// - 縦バーのポーズ … ページ側が `VerticalBarPageTitle` として内容の先頭に描く
///   （カスタムビューの項目を入れるとバーが横帯に戻ってしまうため、ここでは項目を作らない）
///
/// どちらの場合もシステムのタイトルは帯から取り除くが、`navigationTitle(_:)` は
/// アクセシビリティと戻るボタンのために設定したままにしておく。
///
/// 使い方:
/// ```swift
/// NavigationStack {
///     TimetableView(isLoggedIn: $isLoggedIn, title: title, isVerticalBarPose: isVerticalBarPose)
///         .navigationTitle(title)
///         .toolbarTitleDisplayMode(.inline)
///         .mainToolbar(title: title, isVerticalBarPose: isVerticalBarPose, isLoggedIn: $isLoggedIn)
/// }
/// ```
extension View {

    /// ページタイトルと共通のツールバー項目（掲示情報・設定）を追加する
    func mainToolbar(
        title: String,
        isVerticalBarPose: Bool,
        isLoggedIn: Binding<Bool>
    ) -> some View {
        modifier(
            MainToolbarModifier<EmptyView>(
                title: title,
                isVerticalBarPose: isVerticalBarPose,
                isLoggedIn: isLoggedIn,
                extraItems: nil
            )
        )
    }

    /// 共通のツールバー項目に加えて、タブ固有の項目を追加する。
    ///
    /// `trailingExtra` は共通項目（掲示情報・設定）より後ろ（末尾側）に、
    /// `ToolbarSpacer` を挟んで別のグループとして置かれる。
    /// 横バーでは右端の独立したガラスのカプセル、縦バーでは共通項目の下の独立したグループになる
    func mainToolbar<Extra: View>(
        title: String,
        isVerticalBarPose: Bool,
        isLoggedIn: Binding<Bool>,
        @ViewBuilder trailingExtra: @escaping () -> Extra
    ) -> some View {
        modifier(
            MainToolbarModifier(
                title: title,
                isVerticalBarPose: isVerticalBarPose,
                isLoggedIn: isLoggedIn,
                extraItems: trailingExtra
            )
        )
    }
}

// MARK: - 項目の配色

extension View {

    /// 共通ツールバー項目を黒（`.primary`）で描画する。
    ///
    /// `TabView` に付けた `.tint(.appPrimary)` は環境経由でツールバー項目にも継承され、
    /// シンボルがピンクになってしまう。項目ごとに打ち消すことで、タブバーの選択色（appPrimary のまま）や
    /// シート内の配色には影響を与えずにツールバーだけを黒にできる。
    /// 未読バッジはシステムが描くため、赤のまま残る
    func toolbarItemTint() -> some View {
        tint(.primary)
    }
}

// MARK: - モディファイア

/// 共通ツールバーの項目と、それに付随する状態・シートを持つモディファイア。
///
/// タブごとに1つずつ生成されるため、ここで持つのはタブ内で完結する状態だけにする
/// （アプリ全体で1つだけ出すべき表示は `ContentView` 側でホストする）
private struct MainToolbarModifier<Extra: View>: ViewModifier {

    // MARK: - プロパティ

    /// ページタイトル（`navigationTitle(_:)` に渡すものと同じ文字列）
    let title: String

    /// システムのバーが縦バーとして表示されているか
    let isVerticalBarPose: Bool

    @Binding var isLoggedIn: Bool

    /// タブ固有の追加項目（無い場合は nil）。共通項目より後ろに、別グループとして置く
    let extraItems: (() -> Extra)?

    @State private var user: User?
    @State private var showSafariView = false
    @State private var showingUserSettings = false

    /// UserDefaultsの変更を監視して、未読件数などを取り直す
    private let userDefaultsObserver = NotificationCenter.default
        .publisher(for: UserDefaults.didChangeNotification)

    // MARK: - ボディ

    func body(content: Content) -> some View {
        content
            .toolbar { toolbarContent }
            // タイトルはポーズごとに自前で描くため、バーの中のシステムタイトルは常に取り除く
            .hidingSystemNavigationTitle(true)
            .sheet(
                isPresented: $showSafariView,
                onDismiss: {
                    // シートが閉じられた時（下スワイプでも）に実行される
                    NotificationCenter.default.post(name: .announcementSafariDismissed, object: nil)
                }
            ) {
                if let keijiBoardURL = createKeijiBoardURL() {
                    SafariWebView(
                        url: keijiBoardURL,
                        dismissNotification: .announcementSafariDismissed
                    )
                }
            }
            .sheet(isPresented: $showingUserSettings) {
                UserSettingsView(isLoggedIn: $isLoggedIn)
            }
            .onAppear {
                loadUserData()
            }
            .onReceive(userDefaultsObserver) { _ in
                loadUserData()
            }
    }

    // MARK: - ツールバー項目

    /// ツールバーの中身。
    ///
    /// 並び順は「掲示情報 → 設定 →（区切り）→ タブ固有の項目」（縦バーでは上から、横バーでは左から）。
    /// タブ固有の項目は共通項目とは別の物だと分かるよう、`ToolbarSpacer` で切り離して
    /// 独立したグループにする（iOS 26以降。それ以前はグループのガラス自体が無いのでそのまま並べる）。
    /// 収まらない項目は末尾からオーバーフローメニューへ送られるため、末尾に来るタブ固有の項目と
    /// 掲示情報（未読バッジを持つ）を優先して残す。`visibilityPriority(_:)` はiOS 27以降のAPIなので分岐する
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        titleItem
        commonItems
        trailingExtraItem
    }

    /// どのタブにもある共通項目（掲示情報・設定）
    @ToolbarContentBuilder private var commonItems: some ToolbarContent {
        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                announcementsButton
            }
            .visibilityPriority(.high)

            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
            .visibilityPriority(.low)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                announcementsButton
            }

            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
    }

    /// 共通項目の後ろに、区切りを挟んで置くタブ固有の項目
    @ToolbarContentBuilder private var trailingExtraItem: some ToolbarContent {
        if let extraItems {
            if #available(iOS 27.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    extraItems()
                }
                .visibilityPriority(.high)
            } else if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    extraItems()
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    extraItems()
                }
            }
        }
    }

    /// 横バーのポーズでバーの先頭に置くタイトル項目。
    ///
    /// 縦バーのポーズではカスタムビューの項目がバーを横帯へ戻してしまうため、項目自体を作らない
    /// （その場合はページ側の `VerticalBarPageTitle` がタイトルを描く）。
    /// iOS 26以降はツールバー項目にガラスの背景が付くので、タイトルでは打ち消してただの文字に見せる
    @ToolbarContentBuilder private var titleItem: some ToolbarContent {
        if !isVerticalBarPose {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) {
                    titleText
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    titleText
                }
            }
        }
    }

    /// タイトルの文字（押せないように、ヒットテストからは外しておく）。
    ///
    /// ツールバー項目には狭い幅しか提案されず、そのままだと数文字で省略されてしまうため、
    /// `fixedSize(horizontal:vertical:)` で文字の本来の幅を要求する
    private var titleText: some View {
        Text(title)
            .font(PageTitleStyle.font)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(PageTitleStyle.minimumScaleFactor)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityAddTraits(.isHeader)
            .allowsHitTesting(false)
    }

    /// 掲示情報ボタン（未読件数バッジ付き）
    @ViewBuilder private var announcementsButton: some View {
        let label = Label(
            NSLocalizedString("掲示情報", comment: "ツールバー"),
            systemImage: "list.clipboard"
        )

        if #available(iOS 26.0, *) {
            // システム標準のツールバーバッジ（縦バー・オーバーフローメニューでも正しく表示される）
            Button(action: { showSafariView = true }) {
                label
            }
            .badge(unreadBadgeText.map { Text($0) })
            .toolbarItemTint()
        } else {
            // iOS 25以前はツールバー項目のバッジが描画されないため、従来の自前バッジを使う
            Button(action: { showSafariView = true }) {
                ZStack(alignment: .topTrailing) {
                    label

                    if let unreadBadgeText {
                        Text(unreadBadgeText)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(
                                Circle()
                                    .fill(Color.red)
                                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .offset(x: 8, y: -8)
                            .animation(.spring(), value: unreadBadgeText)
                    }
                }
            }
            .toolbarItemTint()
        }
    }

    /// 設定（ユーザー情報）ボタン
    private var settingsButton: some View {
        Button(action: { showingUserSettings = true }) {
            Label(
                NSLocalizedString("設定", comment: "ツールバー"),
                systemImage: "person.crop.circle"
            )
        }
        .toolbarItemTint()
    }

    /// 未読件数のバッジ文字列（0件のときは nil、100件以上は "99+"）
    private var unreadBadgeText: String? {
        guard let unreadCount = user?.allKeijiMidokCnt, unreadCount > 0 else { return nil }
        return unreadCount > 99 ? "99+" : "\(unreadCount)"
    }

    // MARK: - プライベートメソッド

    /// 掲示板URLを生成する
    private func createKeijiBoardURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "password": "",
            "funcId": "Bsd507",
            "autoLoginAuthCd": "",
            "formId": "Bsd50701",
            "encryptedPassword": encryptedPassword,
            "userId": user.username,
            "parameterMap": ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        let encodedLoginInfo = jsonString.webAPIEncoded

        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }

    /// ユーザーデータを読み込む（未読件数が変わったときだけ更新する）。
    /// タブごとに1つずつ動くため、ログは出さず、変化が無ければ状態も触らない
    private func loadUserData() {
        guard let updatedUser = UserService.shared.getCurrentUser() else { return }
        if user == nil || user?.allKeijiMidokCnt != updatedUser.allKeijiMidokCnt {
            user = updatedUser
        }
    }
}
