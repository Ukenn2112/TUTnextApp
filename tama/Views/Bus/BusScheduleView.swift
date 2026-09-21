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

        /// 時刻カードの中身の高さ。
        ///
        /// 「次のバスまで」「選択したバスまで（バス時刻の行が増える）」「本日の運行は終了しました」で
        /// 本来の高さが変わってしまうと、左右の時刻表が別の線から始まってしまう。
        /// いちばん背の高い場面（選択中）の行の高さを常に確保して、両列を同じ線に揃える
        static var timeCardContentHeight: CGFloat {
            let label = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
            let value = UIFont.systemFont(ofSize: 22, weight: .bold).lineHeight
            let detail = UIFont.systemFont(ofSize: 13, weight: .medium).lineHeight
            return label + Spacing.xxs + value + Spacing.xxs + detail
        }
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
        .edgesIgnoringSafeArea(.bottom)
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
                        .foregroundColor(.red)
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
                ProgressView("読み込み中...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                .foregroundColor(.orange)
                .font(.system(size: 14))

            // 1行のメッセージでも2行分の高さを確保し、カードの高さを揃える（文字は縦中央）
            Text(message.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: Self.twoLineTextHeight, alignment: .leading)

            if showChevron, let url = url {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
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
            Picker("スケジュールタイプ", selection: $selectedScheduleType) {
                Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
                Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
                Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, BusLayout.horizontalPadding)
            .onChange(of: selectedScheduleType) { _, _ in
                onChanged()
            }
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
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
                withAnimation {
                    scrollProxy.scrollTo(newValue.rawValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - 共通のチップの並び

    /// 4つのチップと区切り線の並び（どちらの並べ方でも同じ間隔・同じチップ）
    private func chipRow(fillsWidth: Bool) -> some View {
        HStack(spacing: Self.chipSpacing) {
            chip(for: Self.routes[0], fillsWidth: fillsWidth)
            chip(for: Self.routes[1], fillsWidth: fillsWidth)

            Divider()
                .frame(height: Self.dividerHeight)
                .background(Color.gray.opacity(0.3))

            chip(for: Self.routes[2], fillsWidth: fillsWidth)
            chip(for: Self.routes[3], fillsWidth: fillsWidth)
        }
    }

    private func chip(for type: BusSchedule.RouteType, fillsWidth: Bool) -> some View {
        BusRouteChip(
            title: Self.title(for: type),
            // 均等幅のときは、どのチップもいちばん長い路線名の幅を本来の幅として持つ
            sizingTitles: fillsWidth ? Self.routes.map(Self.title(for:)) : nil,
            isSelected: selectedRouteType == type,
            fillsWidth: fillsWidth
        ) {
            selectedRouteType = type
            onChanged()
        }
        .id(type.rawValue)
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

// MARK: - 路線チップ

/// 路線チップ1つ。均等幅でも横スクロールでも、この1つのビューで同じ見た目を描く
private struct BusRouteChip: View {
    let title: String

    /// 幅を揃えるために本来の幅として確保する路線名の一覧。
    /// 均等幅のときだけ渡し、横スクロールのときは nil（＝自分の文字の幅そのまま）
    let sizingTitles: [String]?

    let isSelected: Bool

    /// 与えられた幅いっぱいに広がるかどうか
    let fillsWidth: Bool

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                                ? Color.appPrimary
                                : Color(UIColor.secondarySystemFill)
                        )
                        .shadow(
                            color: isSelected ? Color.appPrimary.opacity(0.3) : Color.clear,
                            radius: 3, x: 0, y: 2)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    /// チップの文字。
    ///
    /// 均等幅のときは、すべての路線名を隠したまま重ねるので、
    /// どのチップの本来の幅もいちばん長い路線名の幅になる。
    /// `ViewThatFits` はその幅で収まるかどうかを測るため、
    /// 均等に分けたときに文字が切れたり縮んだりすることがない
    private var label: some View {
        ZStack {
            if let sizingTitles {
                ForEach(sizingTitles, id: \.self) { sizingTitle in
                    text(sizingTitle)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }

            text(title)
        }
    }

    private func text(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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

    /// 中身の高さを固定するか（2列表示のとき。左右の時刻表を同じ線から始めるため）
    var fixedContentHeight: CGFloat?

    /// このカードが見ている路線（1列表示では選択中の路線）
    private var effectiveRoute: BusSchedule.RouteType {
        route ?? viewModel.selectedRouteType
    }

    /// このカードに出す選択中の便
    private var selectedEntry: BusSchedule.TimeEntry? {
        if let route {
            return viewModel.selectedEntry(on: route)
        }
        return viewModel.selectedTimeEntry
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現在時刻")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.timeFormatter.string(from: viewModel.currentTime))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                if let selectedTime = selectedEntry,
                    viewModel.isTimeEqual(selectedTime, to: viewModel.currentTime) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("バスの出発時刻です")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .transition(.opacity)

                        Text("0分0秒")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                            .transition(.opacity)
                    }
                } else if let nextBus = selectedEntry ?? viewModel.getNextBus(for: effectiveRoute) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(selectedEntry != nil ? "選択したバスまで" : "次のバスまで")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .transition(.opacity)

                        HStack(spacing: 4) {
                            Text(viewModel.getCountdownText(to: nextBus))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(selectedEntry != nil ? .orange : .green)
                                .transition(.opacity)

                            if let note = nextBus.specialNote {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                                    .transition(.opacity)
                            }
                        }

                        if selectedEntry != nil {
                            HStack {
                                Text("バス時刻")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(
                                    "\(String(format: "%02d:%02d", nextBus.hour, nextBus.minute))"
                                )
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                            }
                            .opacity(viewModel.cardInfoAppeared ? 1 : 0)
                            .offset(y: viewModel.cardInfoAppeared ? 0 : 5)
                            .transition(.opacity)
                        }
                    }
                } else {
                    Text("本日の運行は終了しました")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            // 2列表示だけ、いちばん背の高い場面の高さを常に確保して左右のカードの高さを揃える
            .frame(height: fixedContentHeight)

            if showsPinMessage, let pinMessage = viewModel.busSchedule?.pin {
                PinMessageRowView(pinMessage: pinMessage)
            }
        }
        // 白い地のページに置くので、影ではなくアプリ共通の1ptの枠で輪郭を取る
        .outlinedCard()
        .contentShape(Rectangle())
        .onTapGesture {}
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTimeEntry)
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

    /// 表の輪郭の角丸。
    /// 上の2つの角は固定された見出しが、下の2つの角はスクロールする行の入れ物が受け持つ
    private static let tableCornerRadius = CardSurface.cornerRadius

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// この表が見ている路線（1列表示では選択中の路線）
    private var effectiveRoute: BusSchedule.RouteType {
        route ?? viewModel.selectedRouteType
    }

    /// この表の中でその便が選ばれているか。
    /// 1列表示では従来どおり便だけを見る。2列表示では列の路線まで見て、
    /// 反対向きの同じ「分」が一緒に光らないようにする
    private func isSelected(_ time: BusSchedule.TimeEntry) -> Bool {
        if let route {
            return viewModel.isSelected(time, on: route)
        }
        return viewModel.selectedTimeEntry == time
    }

    /// 開いたときに見せたい時間（次のバスの時間）
    private var targetHour: Int? {
        route == nil ? viewModel.scrollToHour : viewModel.scrollHour(for: effectiveRoute)
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
    private func scrollToTarget(_ hour: Int, proxy: ScrollViewProxy) {
        if visibleSchedules.first?.hour == hour {
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
        VStack(spacing: 0) {
            pinnedTableHeader
                .padding(.horizontal, BusLayout.horizontalPadding)
                // 浮かぶ時刻カードと表の間（1列表示・2列表示で同じ16ポイント）
                .padding(.top, BusLayout.Spacing.m)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .center, spacing: BusLayout.Spacing.m) {
                        scheduleRowsView
                            .onChange(of: targetHour) { _, newValue in
                                if let hour = newValue {
                                    withAnimation {
                                        scrollToTarget(hour, proxy: scrollProxy)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                scrollToTarget(hour, proxy: scrollProxy)
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

    private var scheduleRowsView: some View {
        VStack(spacing: 0) {
            if viewModel.selectedScheduleType == .wednesday {
                wednesdaySpecialMessage
            }

            ForEach(Array(visibleSchedules.enumerated()), id: \.element.hour) { index, hourSchedule in
                hourScheduleRow(hourSchedule, rowIndex: index)
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
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .center)
                .padding(.vertical, 12)

            Divider()
                .frame(width: 1)
                .background(Color.gray.opacity(0.3))

            Text("発車時刻")
                .font(.headline)
                .foregroundColor(.secondary)
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
                .foregroundColor(.blue)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }


    private func hourScheduleRow(_ hourSchedule: BusSchedule.HourSchedule, rowIndex: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(hourSchedule.hour)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .center)
                    .padding(.vertical, 12)

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))

                VStack(alignment: .center) {
                    LazyVGrid(columns: minuteColumns, alignment: .center, spacing: 12) {
                        ForEach(hourSchedule.times, id: \.minute) { time in
                            timeEntryView(time)
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
            viewModel.isCurrentHour(hourSchedule.hour, on: effectiveRoute)
                ? Color.currentHourBackground
                : (rowIndex % 2 == 0
                    ? Color(UIColor.systemBackground)
                    : Color(UIColor.quaternarySystemFill))
        )
    }

    private func timeEntryView(_ time: BusSchedule.TimeEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Text("\(String(format: "%02d", time.minute))")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(
                    viewModel.isCurrentOrNextBus(time, on: effectiveRoute) || isSelected(time)
                        ? .white : .primary
                )
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isSelected(time)
                                ? Color.orange.opacity(0.9)
                                : (viewModel.isCurrentOrNextBus(time, on: effectiveRoute)
                                    ? Color.appPrimary : Color.clear)
                        )
                )

            if let note = time.specialNote {
                Text(note)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(9)
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
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.busSchedule?.specialNotes ?? [], id: \.symbol) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text(note.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)

                    Text(note.description)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
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
                .foregroundColor(.red)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.red)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
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
