import SwiftUI

// MARK: - レイアウト定数

/// バス時刻表ページの共通のレイアウト値
enum BusLayout {
    /// ページ内容の列の横の余白。
    /// 時刻表・セグメント・浮動現在時刻カード・横スクロールの行が同じ線に揃うように、
    /// すべてこの値を使う（`.padding(.horizontal)` の既定値と同じ）
    static let horizontalPadding: CGFloat = 16

    /// 4ptを基本にした1本だけの余白の目盛り。
    /// 2列表示の余白・間隔はすべてこの段から選び、ビューに数値を直接書かない
    /// （時間割タブの「今日」ペイン `TodayPaneTokens.Spacing` と同じ目盛り）
    enum Spacing {

        /// 4pt（記号と文字の間）
        static let xxs: CGFloat = 4

        /// 8pt（見出しと下のカードの間）
        static let xs: CGFloat = 8

        /// 12pt（操作の行と行の間）
        static let s: CGFloat = 12

        /// 16pt（ページの横の余白・帯と列の間）
        static let m: CGFloat = 16
    }

    /// 2列表示（Duoの内側ディスプレイ・横向き）だけで使う寸法。
    /// 左右の列はここの値だけを使うので、行の高さも始まりの位置も必ず一致する
    enum TwoPane {

        /// ページ内タイトルと、その下の帯の間
        static let titleBottomSpacing = Spacing.xs

        /// 共有の帯（タイトル・臨時ダイヤ・ピン・操作）と、その下の2列の間。
        /// 帯の中の間隔より1段広くして、帯と列の区切りがひと目で分かるようにする
        static let bandBottomSpacing = Spacing.m

        /// 列の見出しと、その下の時刻カードの間
        static let columnHeaderBottomSpacing = Spacing.xs

        /// 列の見出しの文字
        static var columnTitleFont: Font { .system(size: 16, weight: .semibold) }

        /// 列の見出しの向きの補足
        static var columnHintFont: Font { .system(size: 13) }

        /// 浮かぶ時刻カードの上端の余白（1列表示の `timeCardTopInset` にあたる値）
        static let timeCardTopInset = Spacing.xs

        /// 平らなとき（折り目が無効なとき）の列と列の間。
        /// 左右の列がそれぞれ `BusLayout.horizontalPadding` の余白を持つので、その2つ分になる
        static let columnGutter = BusLayout.horizontalPadding * 2
    }
}

struct BusScheduleView: View {
    // MARK: - プロパティ
    @StateObject private var viewModel = BusScheduleViewModel()
    @EnvironmentObject private var ratingService: RatingService

    /// ページのタイトル（システムのナビゲーションタイトルと同じ値）。
    /// 縦バーのポーズではバーのタイトルを消して、この文字列をページ内容の先頭に描く
    let title: String

    /// システムのバーが縦バーとして表示されているか（判定は `ContentView` が一箇所で行う）
    let isVerticalBarPose: Bool

    /// 浮動現在時刻カードの実測の高さ（時刻表をその分だけ下げる）
    @State private var timeCardHeight: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// ページに与えられている大きさ（2列にするかの判定に使う）
    @State private var containerSize: CGSize = .zero

    /// 浮動現在時刻カードの上端の余白
    private static let timeCardTopInset: CGFloat = 10

    /// 縦バーのポーズで、ページ内タイトルの下に空ける余白
    private static let verticalBarTitleBottomSpacing: CGFloat = 8

    // MARK: - ボディ
    var body: some View {
        Group {
            if #available(iOS 27.1, *), isTwoPane {
                BusTwoPaneView(
                    viewModel: viewModel,
                    title: title,
                    isVerticalBarPose: isVerticalBarPose
                )
            } else {
                singleColumnContent
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearSelection()
                }
        )
        .background(Color(UIColor.systemBackground))
        // 便を押したときの触覚はページで1回だけ返す（2列表示で左右の表が同時に鳴らないように）。
        // 発車による自動解除や選択の復元では鳴らさない
        .selectionHaptic(trigger: viewModel.timeEntryTapCount)
        .ignoresSafeArea(edges: .bottom)
        // 縦バーのポーズでは空のナビゲーションバー帯の分だけ上が空くため、ウィンドウ上端まで広げる。
        // 下端はスクロールする内容なのでシステムに任せる（横バーのポーズでは何もしない）
        .ignoresSafeArea(.container, edges: isVerticalBarPose ? .top : [])
        // セーフエリアを無視した後の大きさ＝このポーズでのページの実寸を読む
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        .onChange(of: isTwoPane, initial: true) { _, twoPane in
            // 現在地による路線の自動切り替えは、2列表示の間だけ止める
            viewModel.isTwoPaneLayout = twoPane
        }
        .onAppear {
            viewModel.setupOnAppear()
            ratingService.recordSignificantEvent()
        }
        .onDisappear {
            viewModel.cleanupOnDisappear()
        }
    }

    // MARK: - 2列の判定

    /// 駅発・駅行を左右に並べるかどうか（判定は時間割タブと同じ `DuoTwoPane`）
    private var isTwoPane: Bool {
        DuoTwoPane.isEnabled(
            containerSize: containerSize, horizontalSizeClass: horizontalSizeClass)
    }

    // MARK: - 1列表示（通常のiPhone・Duoの内側縦向き・外側ディスプレイ・Split View）

    private var singleColumnContent: some View {
        VStack(spacing: 0) {
            if isVerticalBarPose {
                // 縦バーのポーズではバーのタイトル帯を無視して上を詰め、
                // グリフ上端がウィンドウ上端から VerticalBarLayout.edgeMargin の位置に来るように描く
                VerticalBarPageTitle(title: title)
                    .padding(.bottom, Self.verticalBarTitleBottomSpacing)
            }

            if let busSchedule = viewModel.busSchedule {
                // 臨時ダイヤメッセージがある場合は表示
                if let messages = busSchedule.temporaryMessages, !messages.isEmpty {
                    BusTemporaryMessagesView(messages: messages)
                }

                // 時刻表タイプセレクタ（平日/水曜日/土曜日）
                BusScheduleTypeSelector(
                    selectedScheduleType: $viewModel.selectedScheduleType,
                    onChanged: { viewModel.onScheduleTypeChanged() }
                )

                // 路線セレクタ
                BusRouteTypeSelector(
                    selectedRouteType: $viewModel.selectedRouteType,
                    onChanged: { viewModel.onRouteTypeChanged() }
                )

                // 時刻表コンテンツ（浮動時間カードを含む）
                ZStack(alignment: .top) {
                    BusTimeTableContent(viewModel: viewModel)
                        .padding(.top, Self.timeCardTopInset + timeCardHeight)

                    // 浮動現在時刻表示カード
                    BusTimeCardView(viewModel: viewModel)
                        .padding(.horizontal, BusLayout.horizontalPadding)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            timeCardHeight = newHeight
                        }
                        .padding(.top, Self.timeCardTopInset)
                }
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                        .multilineTextAlignment(.center)

                    Button(action: {
                        viewModel.errorMessage = nil
                        viewModel.fetchBusScheduleData()
                    }) {
                        Text("再読み込み")
                    }
                    .padding(.top, 16)
                }
            } else {
                // キャッシュからすぐ出せることが多いので、読み込みが長引いたときだけスケルトンを出す
                BusLoadingPlaceholder(columnCount: 1)
                    .padding(.top, Self.timeCardTopInset)
            }
        }
    }
}

// MARK: - 読み込み中のスケルトン

/// 時刻表を読み込んでいる間の仮の姿（時刻カード＋表の見出し＋数行）。
///
/// 読み込みが `Motion.skeletonDelay` より長引いたときだけ形を出し、それまでは何も描かない。
/// キャッシュから時刻表をすぐ出せる普段の起動では、スケルトンが一瞬ちらつくことはない
struct BusLoadingPlaceholder: View {

    /// 並べる列の数（1列表示は1、2列表示は2）
    let columnCount: Int

    /// 左右の列の間（2列表示のときだけ使う）
    var columnSpacing: CGFloat = BusLayout.TwoPane.columnGutter

    /// 仮に並べる表の行の数
    private static let rowCount = 5

    /// 1行に並べる仮の分チップの数
    private static let minuteCount = 4

    var body: some View {
        DelayedSkeletonGate(isLoading: true) { showsSkeleton in
            Group {
                if showsSkeleton {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        ForEach(0..<max(columnCount, 1), id: \.self) { _ in
                            column
                        }
                    }
                    .padding(.horizontal, BusLayout.horizontalPadding)
                    .skeleton(true)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// 1列分（時刻カード・表の見出し・行）
    private var column: some View {
        VStack(spacing: BusLayout.Spacing.m) {
            timeCard
            table
        }
        .frame(maxWidth: .infinity)
    }

    /// 時刻カードの形（左に現在時刻、右に残り時間）
    private var timeCard: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: BusLayout.Spacing.xs) {
                SkeletonBlock(width: 56, height: 12)
                SkeletonBlock(width: 72, height: 22)
            }
            Spacer(minLength: BusLayout.Spacing.m)
            VStack(alignment: .trailing, spacing: BusLayout.Spacing.xs) {
                SkeletonBlock(width: 72, height: 12)
                SkeletonBlock(width: 104, height: 22)
            }
        }
        .outlinedCard()
    }

    /// 表の見出しと数行
    private var table: some View {
        VStack(spacing: 0) {
            SkeletonBlock(height: 44, cornerRadius: 0)
            ForEach(0..<Self.rowCount, id: \.self) { _ in
                HStack(spacing: BusLayout.Spacing.m) {
                    SkeletonBlock(width: 28, height: 20)
                        .frame(width: 70 - BusLayout.Spacing.m)
                    HStack(spacing: BusLayout.Spacing.s) {
                        ForEach(0..<Self.minuteCount, id: \.self) { _ in
                            SkeletonBlock(width: 36, height: 36)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, BusLayout.Spacing.s)
            }
        }
        .clipShape(.rect(cornerRadius: CardSurface.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .strokeBorder(CardSurface.outlineStroke, lineWidth: CardSurface.outlineWidth)
        )
    }
}

// MARK: - 臨時ダイヤメッセージビュー

struct BusTemporaryMessagesView: View {
    let messages: [BusSchedule.TemporaryMessage]

    /// メッセージ本文2行分の高さ（フォントの行高から算出）
    private static let twoLineTextHeight: CGFloat =
        ceil(UIFont.systemFont(ofSize: 13, weight: .medium).lineHeight * 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(messages, id: \.title) { message in
                        messageCard(message)
                    }
                }
                .padding(.horizontal, BusLayout.horizontalPadding)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
            .clippedToHorizontalSafeArea(contentInset: BusLayout.horizontalPadding)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func messageCard(_ message: BusSchedule.TemporaryMessage) -> some View {
        Group {
            if let url = URL(string: message.url) {
                messageCardContent(message, showChevron: true, url: url)
            } else {
                messageCardContent(message, showChevron: false, url: nil)
            }
        }
    }

    private func messageCardContent(
        _ message: BusSchedule.TemporaryMessage, showChevron: Bool, url: URL? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))

            // 1行のメッセージでも2行分の高さを確保し、カードの高さを揃える（文字は縦中央）
            Text(message.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: Self.twoLineTextHeight, alignment: .leading)

            if showChevron, let url = url {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 260)
        // 白い地に浮かせず、注意を表すオレンジの枠だけで輪郭を取る
        .background(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .fill(CardSurface.pageFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .stroke(Color.orange.opacity(0.4), lineWidth: CardSurface.outlineWidth)
        )
    }
}

// MARK: - 時刻表タイプセレクタ

struct BusScheduleTypeSelector: View {
    @Binding var selectedScheduleType: BusSchedule.ScheduleType
    var onChanged: () -> Void

    var body: some View {
        HStack {
            Picker("スケジュールタイプ", selection: userSelection) {
                Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
                Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
                Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, BusLayout.horizontalPadding)
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    /// 利用者がセグメントを押したときだけ `onChanged` を呼ぶ選択。
    ///
    /// `onChange(of:)` で見張ると、起動時の曜日合わせやディープリンクのように
    /// プログラムから曜日を変えたときにも、選んだ便とライブアクティビティを捨ててしまう
    private var userSelection: Binding<BusSchedule.ScheduleType> {
        Binding(
            get: { selectedScheduleType },
            set: { newValue in
                guard newValue != selectedScheduleType else { return }
                // 時間ごとの行（時で識別）と分のチップ（分で識別）が、その場で形を変えて入れ替わる
                withMotion(Motion.standard) {
                    selectedScheduleType = newValue
                    onChanged()
                }
            }
        )
    }
}

// MARK: - 路線セレクタ

/// 路線を選ぶチップの行。
///
/// 横に余裕があるポーズ（iPhone Duoの内側ディスプレイの縦向きなど）では、
/// 4つのチップを均等の幅に広げ、上のセグメントや下の時刻カードと同じ線まで
/// ページ内容の列いっぱいに並べる。
/// 本来の幅で収まらないとき（通常のiPhone・外側ディスプレイ・Split View・
/// 大きな文字・訳語の長い言語）は、従来どおりの横スクロールの行に戻る。
struct BusRouteTypeSelector: View {
    @Binding var selectedRouteType: BusSchedule.RouteType
    var onChanged: () -> Void

    /// チップとチップ・チップと区切り線の間隔（どちらの並べ方でも同じ値を使う）
    private static let chipSpacing: CGFloat = 15

    /// チップの行の上下の余白（選択中のチップの影がはみ出す分）
    private static let rowVerticalPadding: CGFloat = 5

    /// 「発」と「行」を分ける区切り線の高さ
    private static let dividerHeight: CGFloat = 20

    /// 行に並べる路線。区切り線は2番目と3番目の間（＝「発」と「行」の間）に入る
    private static let routes: [BusSchedule.RouteType] = [
        .fromSeisekiToSchool,
        .fromNagayamaToSchool,
        .fromSchoolToSeiseki,
        .fromSchoolToNagayama,
    ]

    var body: some View {
        // 先に均等幅の行を測る。その本来の幅は「いちばん長い路線名が切れない幅」×4なので、
        // 収まると判断されたときは、均等に分けても必ず文字が切れない
        ViewThatFits(in: .horizontal) {
            evenWidthRow
            scrollingRow
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - 均等幅で内容の列いっぱいに並べる

    private var evenWidthRow: some View {
        chipRow(fillsWidth: true)
            .padding(.horizontal, BusLayout.horizontalPadding)
            .padding(.vertical, Self.rowVerticalPadding)
    }

    // MARK: - 横スクロールの行（本来の幅が収まらないとき）

    private var scrollingRow: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                chipRow(fillsWidth: false)
                    .padding(.horizontal, BusLayout.horizontalPadding)
                    .padding(.vertical, Self.rowVerticalPadding)
            }
            .clippedToHorizontalSafeArea(contentInset: BusLayout.horizontalPadding)
            .onChange(of: selectedRouteType) { _, newValue in
                // チップの id は路線そのもの（`SelectionChipRow` が付ける）
                withMotion(Motion.standard) {
                    scrollProxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - 共通のチップの並び

    /// 4つのチップと区切り線の並び（どちらの並べ方でも同じ間隔・同じチップ）。
    /// 選択中の塗りはチップの間を滑って移り、押したときだけ触覚を返す（`SelectionChipRow`）
    private func chipRow(fillsWidth: Bool) -> some View {
        SelectionChipRow(
            Self.routes,
            selection: animatedSelection,
            spacing: Self.chipSpacing,
            fillsWidth: fillsWidth,
            // 「発」と「行」の間に区切り線を入れる
            separatorBefore: [Self.routes[2]],
            separatorHeight: Self.dividerHeight,
            onSelect: { _ in
                withMotion(Motion.standard) {
                    onChanged()
                }
            }
        ) { type in
            Self.chipLabel(
                title: Self.title(for: type),
                // 均等幅のときは、どのチップもいちばん長い路線名の幅を本来の幅として持つ
                sizingTitles: fillsWidth ? Self.routes.map(Self.title(for:)) : nil
            )
        }
    }

    /// 路線の選択。
    ///
    /// 利用者がチップを押したときだけ `SelectionChipRow` から書き込まれる。
    /// 時刻表の行（時で識別）と分のチップ（分で識別）もその場で形を変えて入れ替わるよう、
    /// チップの塗りだけでなくページ全体を `Motion.standard` で動かす
    private var animatedSelection: Binding<BusSchedule.RouteType> {
        Binding(
            get: { selectedRouteType },
            set: { newValue in
                withMotion(Motion.standard) {
                    selectedRouteType = newValue
                }
            }
        )
    }

    /// チップの文字。
    ///
    /// 均等幅のときは、すべての路線名を隠したまま重ねるので、
    /// どのチップの本来の幅もいちばん長い路線名の幅になる。
    /// `ViewThatFits` はその幅で収まるかどうかを測るため、
    /// 均等に分けたときに文字が切れたり縮んだりすることがない
    private static func chipLabel(title: String, sizingTitles: [String]?) -> some View {
        ZStack {
            if let sizingTitles {
                ForEach(sizingTitles, id: \.self) { sizingTitle in
                    chipText(sizingTitle)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }

            chipText(title)
        }
    }

    private static func chipText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// 路線の表示名
    private static func title(for type: BusSchedule.RouteType) -> String {
        switch type {
        case .fromSeisekiToSchool:
            return NSLocalizedString("聖蹟桜ヶ丘駅発", comment: "")
        case .fromNagayamaToSchool:
            return NSLocalizedString("永山駅発", comment: "")
        case .fromSchoolToSeiseki:
            return NSLocalizedString("聖蹟桜ヶ丘駅行", comment: "")
        case .fromSchoolToNagayama:
            return NSLocalizedString("永山駅行", comment: "")
        }
    }
}

// MARK: - 浮動時間カードビュー

struct BusTimeCardView: View {
    @ObservedObject var viewModel: BusScheduleViewModel

    /// このカードが受け持つ路線。
    /// nil なら従来どおり「いま選んでいる路線」（1列表示）。
    /// 2列表示では列ごとの路線を渡し、その列の次のバス・その列で選んだ便だけを出す
    var route: BusSchedule.RouteType?

    /// ピンメッセージをこのカードの中に出すかどうか。
    /// 2列表示ではページ共通の情報なので、左右に2回出さず帯の側で1回だけ出す
    var showsPinMessage: Bool = true

    /// いちばん背の高い場面（選択中＝バス時刻の行がある）の高さを常に確保するか。
    /// 2列表示で左右の時刻表を同じ線から始めるために使う
    var reservesTallestHeight: Bool = false

    /// このカードが見ている路線（1列表示では選択中の路線）
    private var effectiveRoute: BusSchedule.RouteType {
        route ?? viewModel.selectedRouteType
    }

    /// このカードに出す選択中の便（別の路線で選んだ便は出さない）
    private var selectedEntry: BusSchedule.TimeEntry? {
        viewModel.selectedEntry(on: effectiveRoute)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 秒のカウントダウンはカードの中だけで描き直す（ページの残りは分の境目でしか変わらない）。
            // 刻みはページの時計の秒の境目に合わせ、表示が秒の途中でずれて進まないようにする
            TimelineView(.periodic(from: BusScheduleViewModel.nextSecondBoundary(), by: 1)) { context in
                timeRow(now: BusScheduleViewModel.pageTime(from: context.date))
            }

            if showsPinMessage, let pinMessage = viewModel.busSchedule?.pin {
                PinMessageRowView(pinMessage: pinMessage)
            }
        }
        // 白い地のページに置くので、影ではなくアプリ共通の1ptの枠で輪郭を取る
        .outlinedCard()
        .contentShape(Rectangle())
        .onTapGesture {}
        // カードには `.animation` を付けない（中の `TimelineView` が毎秒描き直すため）。
        // 選択の変化は ViewModel の `withMotion` に乗って動き、毎秒の変化は数字の `Text` だけが動く
    }

    /// 現在時刻と、次のバス（または選んだ便）までの残り時間の行
    private func timeRow(now: Date) -> some View {
        ZStack {
            if reservesTallestHeight {
                tallestLayoutTemplate
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現在時刻")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(viewModel.timeFormatter.string(from: now))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                countdown(now: now)
            }
        }
    }

    @ViewBuilder
    private func countdown(now: Date) -> some View {
        let entry = selectedEntry
        if let selectedTime = entry, viewModel.isTimeEqual(selectedTime, to: now) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("バスの出発時刻です")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .transition(.opacity)

                Text("0分0秒")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        } else if let nextBus = entry ?? viewModel.getNextBus(for: effectiveRoute, at: now) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry != nil ? "選択したバスまで" : "次のバスまで")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)

                HStack(spacing: 4) {
                    countdownValue(viewModel.getCountdownText(to: nextBus, now: now))
                        .foregroundStyle(entry != nil ? .orange : .green)
                        .transition(.opacity)

                    if let note = nextBus.specialNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 4))
                            .transition(.opacity)
                    }
                }

                if entry != nil {
                    HStack {
                        Text("バス時刻")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(
                            "\(String(format: "%02d:%02d", nextBus.hour, nextBus.minute))"
                        )
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                    }
                    // 便を選んだ変更（ViewModel の withMotion）に乗って、下から持ち上がって現れる
                    .motionTransition(.rise)
                }
            }
        } else {
            Text("本日の運行は終了しました")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// 残り時間（"12分34秒" など）を、数字と単位に分けて描く。
    ///
    /// 数字だけを `numericText(countsDown:)` で入れ替えるので、毎秒の変化は変わった桁だけが下へ流れる。
    /// アニメーションはこの数字の `Text` にだけ付け、カードや `TimelineView` の外側には付けない。
    /// VoiceOver には分けずに元の1つの文として読ませる
    private func countdownValue(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(BusCountdownPart.parts(of: text)) { part in
                Text(verbatim: part.value)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .motionAnimation(Motion.quick, value: part.value)
                Text(verbatim: part.unit)
            }
        }
        .font(.system(size: 22, weight: .bold))
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }

    /// いちばん背の高い場面（見出し・残り時間・バス時刻の3行）と同じ文字・同じ間隔の見えない型。
    ///
    /// 数値で高さを決めずに実際の文字で場所を取るので、SwiftUIの文字サイズ
    /// （`dynamicTypeSize` の上限や固定を含む）がそのまま反映される
    private var tallestLayoutTemplate: some View {
        VStack(spacing: 4) {
            Text(verbatim: " ")
                .font(.subheadline)
            Text(verbatim: " ")
                .font(.system(size: 22, weight: .bold))
            Text(verbatim: " ")
                .font(.system(size: 13, weight: .medium))
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

// MARK: - 残り時間の数字と単位

/// 残り時間の文の、数字1つとその後ろの単位（"12" と "分"、"34" と "秒"）。
///
/// 文そのものは従来どおりの翻訳（`%d分%d秒` / `%d時間%d分%d秒`）で作り、
/// できあがった文を数字の並びとそれ以外で切り分ける。どの言語でも数字が単位より前に来るので、
/// 新しい翻訳の項目を増やさずに、数字だけを入れ替えるアニメーションができる
struct BusCountdownPart: Identifiable, Equatable {

    /// 末尾から数えた位置（秒が0、分が1、時間が2）。
    /// 時間の桁が消えたり増えたりしても、秒と分の数字は同じビューのまま入れ替わる
    let id: Int

    /// 数字（先頭に数字の無い文なら空）
    let value: String

    /// 数字の後ろの文字（単位と区切りの空白）
    let unit: String

    /// 文を「数字＋単位」の組に切り分ける
    static func parts(of text: String) -> [BusCountdownPart] {
        var pairs: [(value: String, unit: String)] = []
        var value = ""
        var unit = ""
        for character in text {
            if character.isASCII, character.isNumber {
                if !unit.isEmpty {
                    pairs.append((value, unit))
                    value = ""
                    unit = ""
                }
                value.append(character)
            } else {
                unit.append(character)
            }
        }
        if !value.isEmpty || !unit.isEmpty {
            pairs.append((value, unit))
        }
        let count = pairs.count
        return pairs.enumerated().map { index, pair in
            BusCountdownPart(id: count - 1 - index, value: pair.value, unit: pair.unit)
        }
    }
}

// MARK: - ピンメッセージ行ビュー

/// ピンメッセージの1行（1列表示では時刻カードの中、2列表示では共有の帯に置く）
struct PinMessageRowView: View {
    let pinMessage: BusSchedule.PinMessage

    var body: some View {
        if #available(iOS 26.0, *) {
            rowContent
                .glassEffect(.regular.tint(.orange.opacity(0.15)), in: RoundedRectangle(cornerRadius: 10))
        } else {
            rowContent
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                )
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)

            Text(pinMessage.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.8)

            Spacer()

            if let url = URL(string: pinMessage.url) {
                Link(destination: url) {
                    HStack(spacing: 3) {
                        Text("詳細")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 0.5)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - 時刻表コンテンツ

struct BusTimeTableContent: View {
    @ObservedObject var viewModel: BusScheduleViewModel

    /// この表が受け持つ路線。
    /// nil なら従来どおり「いま選んでいる路線」（1列表示）。2列表示では列ごとの路線を渡す
    var route: BusSchedule.RouteType?

    /// 表の下に「備考」を出すかどうか。
    /// 備考は路線ごとではなくページ全体に効く注記なので、
    /// 2列表示では左右に2回出さず、右（駅行）の列だけで1回出す
    var showsSpecialNotes: Bool = true

    /// 自動スクロールの行き先にする「行のいちばん上」（スクロールする内容の先頭）
    private static let tableTopID = "bus_table_top"

    /// 開いたときの自動スクロールを、表の配置が済むまで待つ時間（秒）
    private static let initialScrollDelay: Double = 0.5

    /// 表の輪郭の角丸。
    /// 上の2つの角は固定された見出しが、下の2つの角はスクロールする行の入れ物が受け持つ
    private static let tableCornerRadius = CardSurface.cornerRadius

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// この表が最後に自動スクロールした時間。
    /// 毎分の時計では次のバスの時間が変わったときだけスクロールし、
    /// 利用者が自分でスクロールした位置を分の境目ごとに引き戻さない
    @State private var lastScrolledHour: Int?

    /// この表が見ている路線（1列表示では選択中の路線）
    private var effectiveRoute: BusSchedule.RouteType {
        route ?? viewModel.selectedRouteType
    }

    /// この表の中でその便が選ばれているか。
    /// 1列表示でも2列表示でも路線まで見るので、反対向きの同じ「分」が一緒に光ったり、
    /// 2列表示で別の路線に選んだ便が1列に戻ったときに違う路線の表で光ったりしない
    private func isSelected(_ time: BusSchedule.TimeEntry) -> Bool {
        viewModel.isSelected(time, on: effectiveRoute)
    }

    /// 開いたときに見せたい時間（次のバスの時間）
    private var targetHour: Int? {
        viewModel.scrollHour(for: effectiveRoute)
    }

    /// 表に並べる時間帯（バスの無い時間帯は行にしない）
    private var visibleSchedules: [BusSchedule.HourSchedule] {
        viewModel.getFilteredSchedule(for: effectiveRoute).hourSchedules.filter { !$0.times.isEmpty }
    }

    /// 目当ての時間の行が見えるところまでスクロールする。
    ///
    /// 見出し行（時間｜発車時刻）はスクロールの外にあり、スクロール領域の上端は見出しのすぐ下なので、
    /// 行の上端を上端に合わせるだけで、その行は見出しに隠れず丸ごと見える。
    /// 目当ての行が表の先頭のときだけは、その上にある注記（水曜日の特別ダイヤ）も見えるように、
    /// 行ではなく内容の先頭に合わせる（＝いちばん上で止まる）
    private func scrollToTarget(_ hour: Int, firstHour: Int?, proxy: ScrollViewProxy) {
        lastScrolledHour = hour
        if firstHour == hour {
            proxy.scrollTo(Self.tableTopID, anchor: .top)
        } else {
            proxy.scrollTo("hour_\(hour)", anchor: .top)
        }
    }

    /// 分チップのカラム。
    /// 通常のiPhone（コンパクト幅）は従来どおり5列固定、レギュラー幅ではチップ幅を保ったまま横幅いっぱいに並べる
    private var minuteColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 50, maximum: 50), spacing: 8)]
        }
        return Array(repeating: GridItem(.fixed(50), spacing: 8), count: 5)
    }

    /// 表はひとつづきの角丸の入れ物だが、上の一段（見出し）だけがスクロールの外にあり、
    /// 行はその下の同じ幅・同じ枠の中を動く。
    /// 見出しと行はスクロール領域を境に接しているだけで重ならないので、
    /// 時刻カードと見出しの間や見出しの上に行が覗くことは構造上ありえない
    var body: some View {
        // 表の行と次のバスは描き直しのたびに1回だけ求め、各行・各分チップへ配る
        let schedules = visibleSchedules
        let nextBus = viewModel.getNextBus(for: effectiveRoute)
        let firstHour = schedules.first?.hour

        VStack(spacing: 0) {
            pinnedTableHeader
                .padding(.horizontal, BusLayout.horizontalPadding)
                // 浮かぶ時刻カードと表の間（1列表示・2列表示で同じ16ポイント）
                .padding(.top, BusLayout.Spacing.m)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .center, spacing: BusLayout.Spacing.m) {
                        scheduleRowsView(schedules, nextBus: nextBus)
                            // 次のバスの時間が変わったときだけ動かす（例: 10:59 の次が 11:05 になった）
                            .onChange(of: targetHour) { _, newValue in
                                if let hour = newValue, hour != lastScrolledHour {
                                    withMotion(Motion.standard) {
                                        scrollToTarget(hour, firstHour: firstHour, proxy: scrollProxy)
                                    }
                                }
                            }
                            // 路線・駅・曜日の変更やフォアグラウンド復帰では、時間が同じでも位置を戻す
                            .onChange(of: viewModel.scrollRequestID) { _, _ in
                                if let hour = targetHour {
                                    // 路線・曜日の変更では行の入れ替え（Motion.standard）と同じ長さで寄せる
                                    withMotion(Motion.standard) {
                                        scrollToTarget(hour, firstHour: firstHour, proxy: scrollProxy)
                                    }
                                }
                            }

                        if showsSpecialNotes {
                            specialNotesView
                        }
                    }
                    .padding(.horizontal, BusLayout.horizontalPadding)
                    // 最後の行・備考を最後まで送り出せるだけの下の余白（左右の余白と同じ値）
                    .padding(.bottom, BusLayout.horizontalPadding)
                    // スクロールする内容のいちばん上＝スクロールの行き先「表の頭」
                    .id(Self.tableTopID)
                }
                .onAppear {
                    if let hour = targetHour {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.initialScrollDelay) {
                            withMotion(Motion.standard) {
                                scrollToTarget(hour, firstHour: firstHour, proxy: scrollProxy)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - 表の輪郭

    /// 見出しの形（上の2つの角だけ丸い）
    private var headerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: Self.tableCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Self.tableCornerRadius
        )
    }

    /// スクロールする行の入れ物の形（下の2つの角だけ丸い）
    private var bodyShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: Self.tableCornerRadius,
            bottomTrailingRadius: Self.tableCornerRadius,
            topTrailingRadius: 0
        )
    }

    // MARK: - サブビュー

    /// 常に時刻カードの真下に留まる見出し（表の上の一段）。
    /// 塗り・列の区切り・幅は下の行とまったく同じで、枠の下辺が行を隠す細い線になる
    private var pinnedTableHeader: some View {
        tableHeader
            .background(Color(UIColor.systemFill))
            .clipShape(headerShape)
            .overlay(
                headerShape
                    .strokeBorder(CardSurface.outlineStroke, lineWidth: CardSurface.outlineWidth)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.clearSelection()
            }
    }

    private func scheduleRowsView(
        _ schedules: [BusSchedule.HourSchedule], nextBus: BusSchedule.TimeEntry?
    ) -> some View {
        VStack(spacing: 0) {
            if viewModel.selectedScheduleType == .wednesday {
                wednesdaySpecialMessage
            }

            ForEach(Array(schedules.enumerated()), id: \.element.hour) { index, hourSchedule in
                hourScheduleRow(hourSchedule, rowIndex: index, nextBus: nextBus)
            }
        }
        // 表の中の縞模様はそのまま。外側だけカードと同じ白地＋1ptの枠にする
        .background(CardSurface.pageFill)
        .clipShape(bodyShape)
        .overlay(
            bodyShape
                .strokeBorder(CardSurface.outlineStroke, lineWidth: CardSurface.outlineWidth)
                // 枠の上辺は見出しの下辺と重なって線が二重に見えるため、
                // 角丸の分だけ上へ伸ばして、スクロール領域の外（見出しの側）へ逃がす
                .padding(.top, -Self.tableCornerRadius)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.clearSelection()
        }
    }

    /// 見出しの中身（時間｜発車時刻）。VoiceOverでは1つの見出しとして読む
    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("時間")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .center)
                .padding(.vertical, 12)

            Divider()
                .frame(width: 1)
                .background(Color.gray.opacity(0.3))

            Text("発車時刻")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        }
        // 見出しはスクロールの外（縦に伸びる入れ物の中）にあるので、
        // 列の区切り線に引っ張られて背が伸びないよう、文字の分の高さだけを取る
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var wednesdaySpecialMessage: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }


    private func hourScheduleRow(
        _ hourSchedule: BusSchedule.HourSchedule, rowIndex: Int, nextBus: BusSchedule.TimeEntry?
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(hourSchedule.hour)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(width: 70, alignment: .center)
                    .padding(.vertical, 12)

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))

                VStack(alignment: .center) {
                    LazyVGrid(columns: minuteColumns, alignment: .center, spacing: 12) {
                        ForEach(hourSchedule.times, id: \.minute) { time in
                            timeEntryView(time, isNextBus: time == nextBus)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearSelection()
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .id("hour_\(hourSchedule.hour)")
        .background(
            (nextBus?.hour == hourSchedule.hour
                ? Color.currentHourBackground
                : (rowIndex % 2 == 0
                    ? Color(UIColor.systemBackground)
                    : Color(UIColor.quaternarySystemFill)))
                // 次のバスの時間が移ったときは、行の塗りも静かに移す
                .motionAnimation(Motion.quick, value: nextBus?.hour == hourSchedule.hour)
        )
    }

    /// 分のチップの塗りの状態（次のバス→選んだ便の切り替えも塗りの変化として動かす）
    private struct ChipHighlight: Equatable {
        let isNextBus: Bool
        let selected: Bool
    }

    private func timeEntryView(_ time: BusSchedule.TimeEntry, isNextBus: Bool) -> some View {
        let selected = isSelected(time)
        return ZStack(alignment: .topTrailing) {
            Text("\(String(format: "%02d", time.minute))")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(isNextBus || selected ? .white : .primary)
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            selected
                                ? Color.orange.opacity(0.9)
                                : (isNextBus ? Color.appPrimary : Color.clear)
                        )
                )
                // 次のバス・選んだ便の塗りは、チップごとに同時に（順番に遅らせず）切り替える
                .motionAnimation(Motion.quick, value: ChipHighlight(isNextBus: isNextBus, selected: selected))

            if let note = time.specialNote {
                Text(note)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red.opacity(0.8))
                    .clipShape(.rect(cornerRadius: 9))
                    .offset(x: 8, y: -4)
            }
        }
        .frame(width: 50, height: 36)
        .onTapGesture {
            viewModel.handleTimeEntryTap(time, on: effectiveRoute)
        }
    }

    private var specialNotesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("備考")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.busSchedule?.specialNotes ?? [], id: \.symbol) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text(note.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.8))
                        .clipShape(.rect(cornerRadius: 10))

                    Text(note.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.selectedScheduleType != .wednesday {
                wednesdayWarningMessage
            }
        }
        // 画面幅ではなく、親（左右16ポイントのパディングを持つScrollView内のVStack）の幅に合わせる
        .frame(maxWidth: .infinity)
        .outlinedCard()
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private var wednesdayWarningMessage: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - プレビュー

#Preview {
    BusScheduleViewPreviewHost()
        .environmentObject(RatingService.shared)
        .environmentObject(GoogleOAuthService.shared)
}

private struct BusScheduleViewPreviewHost: View {
    @State private var selectedTab = 0
    @State private var isLoggedIn = true

    private let title = NSLocalizedString("スクールバス", comment: "ヘッダータイトル")

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BusScheduleView(title: title, isVerticalBarPose: false)
                    .navigationTitle(title)
                    .toolbarTitleDisplayMode(.inline)
                    .mainToolbar(title: title, isVerticalBarPose: false, isLoggedIn: $isLoggedIn)
            }
            .tabItem {
                Label(NSLocalizedString("バス", comment: "タブバー"), systemImage: "bus")
            }
            .tag(0)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("時間割", comment: "タブバー"), systemImage: "calendar")
                }
                .tag(1)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("課題", comment: "タブバー"), systemImage: "pencil.line")
                }
                .tag(2)

            Color.clear
                .tabItem {
                    Label(NSLocalizedString("その他", comment: "タブバー"), systemImage: "ellipsis.circle")
                }
                .tag(3)
        }
        .tint(.appPrimary)
    }
}
