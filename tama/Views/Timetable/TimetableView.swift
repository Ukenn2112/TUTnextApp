import SwiftUI

// MARK: - 選択中の授業

/// 2ペイン表示で右側に出している授業の位置（曜日キーと時限キー）
struct CourseSelection: Hashable {
    let day: String
    let period: String
}

// MARK: - 時間割ページ

struct TimetableView: View {
    // MARK: - プロパティ
    @StateObject private var viewModel = TimetableViewModel()
    @Binding var isLoggedIn: Bool
    /// ページのタイトル（システムのナビゲーションタイトルと同じ値）。
    /// 縦バーのポーズではバーのタイトルを消して、この文字列をページ内容の先頭に描く
    let title: String
    /// システムのバーが縦バーとして表示されているか（Duoの外側ディスプレイ・内側横向き・Split View）。
    /// 判定は `ContentView` が一箇所で行い、ツールバー側と同じ値をここへ渡す
    let isVerticalBarPose: Bool
    /// バスタブへ切り替える（「今日」ペインのバスを押したときに使う。路線も一緒に切り替える）
    var onOpenBus: (BusSchedule.RouteType) -> Void = { _ in }
    /// 課題タブへ切り替える（「今日」ペインの「課題をすべて見る」を押したときに使う）
    var onOpenAssignments: () -> Void = {}
    @EnvironmentObject private var ratingService: RatingService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // フォアグラウンド復帰通知オブザーバー
    @State private var willEnterForegroundObserver: NSObjectProtocol?
    // 掲示リストSafariView閉じる通知オブザーバー
    @State private var announcementSafariDismissObserver: NSObjectProtocol?
    /// タブの内容に与えられている大きさ（2ペインにするかの判定に使う）
    @State private var containerSize: CGSize = .zero
    /// 右ペインに出している授業（nil なら「今日」ペイン）
    @State private var selection: CourseSelection?
    /// 左ペインが解いた時間割の縦の目盛り。
    /// 右ペインはこれを受け取って、自分の寸法を計算し直さずに左の行に揃える
    @State private var gridMetrics: TimetableGridMetrics = .unavailable
    /// セルを出し終えたか。最初の読み込みが終わるまではセルの代わりにスケルトン（空きセルの形）を描く。
    /// 一度出したら戻さないので、タブを行き来しても入れ替えの動きは繰り返さない
    @State private var hasRevealedCells = false

    // 曜日インデックスを表示用文字列に変換するヘルパー
    private func weekdayString(from index: String) -> String {
        guard let idx = Int(index), idx >= 1 && idx <= 7 else { return "" }
        let weekdays = [
            NSLocalizedString("月", comment: ""),
            NSLocalizedString("火", comment: ""),
            NSLocalizedString("水", comment: ""),
            NSLocalizedString("木", comment: ""),
            NSLocalizedString("金", comment: ""),
            NSLocalizedString("土", comment: ""),
            NSLocalizedString("日", comment: "")
        ]
        return weekdays[idx - 1]
    }

    private let presetColors = Color.coursePresets

    // MARK: - ボディ
    var body: some View {
        Group {
            if #available(iOS 27.1, *), isTwoPane {
                twoPaneLayout
            } else {
                gridPane
            }
        }
        // 縦バーのポーズではウィンドウの上端・下端まで内容を広げ、
        // 上下とも VerticalBarLayout.edgeMargin だけ端から離した位置に内容を置く
        // （バーのタイトル帯は mainToolbar 側で消してある）
        .ignoresSafeArea(.container, edges: ignoredEdges)
        // セーフエリアを無視した後の大きさ＝このポーズでのページの実寸を読む
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        .onChange(of: isTwoPane) { _, twoPane in
            // 縦向き・外側ディスプレイ・Split Viewへ移ったら、行き場の無くなる選択は捨てる
            if !twoPane {
                selection = nil
            }
        }
        #if DEBUG
        // 起動引数で指定されたときだけ、読み込み後の時間割から最初の授業を選ぶ
        .onChange(of: debugSelectionTrigger, initial: true) { _, _ in
            applyDebugSelectionIfNeeded()
        }
        #endif
        .onAppear {
            viewModel.fetchTimetableData()
            // 時間割表示の重要イベントを記録
            ratingService.recordSignificantEvent()
            // アプリがフォアグラウンドに復帰した時にページを更新
            willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    print("TimetableView: アプリがフォアグラウンドに復帰しました")
                    viewModel.fetchTimetableData()

                    // 通知設定の状態を確認してサーバーと同期
                    NotificationService.shared.checkAuthorizationStatus()
                    NotificationService.shared.syncNotificationStatusWithServer()
                }
            }

            // 掲示リストのSafariViewが閉じられた時の通知を受け取る
            announcementSafariDismissObserver = NotificationCenter.default.addObserver(
                forName: .announcementSafariDismissed,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    print("TimetableView: 掲示リストのSafariViewが閉じられました")
                    viewModel.fetchTimetableData()
                }
            }
        }
        .onDisappear {
            // 通知オブザーバーを削除
            if let observer = willEnterForegroundObserver {
                NotificationCenter.default.removeObserver(observer)
                willEnterForegroundObserver = nil
            }

            // 掲示リストSafari閉じる通知観察者を削除
            if let observer = announcementSafariDismissObserver {
                NotificationCenter.default.removeObserver(observer)
                announcementSafariDismissObserver = nil
            }
        }
    }

    /// セーフエリアを無視する辺（縦バーのポーズでのみ上下を無視し、ウィンドウの端を基準にする）
    private var ignoredEdges: Edge.Set {
        isVerticalBarPose ? [.top, .bottom] : []
    }

    // MARK: - 2ペインの判定

    /// 時間割と「今日」を左右に並べるかどうか。
    ///
    /// 幅がレギュラーで、かつページが縦より横に長いとき（＝Duoの内側ディスプレイの横向き）だけ2ペインにする。
    /// 内側の縦向き・外側ディスプレイ・Split View・通常のiPhoneは従来どおり1ペイン＋シート。
    /// `ArrangementView` の内部状態は読めないので、判定はここで自分の大きさから行う
    private var isTwoPane: Bool {
        guard #available(iOS 27.1, *) else { return false }
        guard horizontalSizeClass == .regular else { return false }
        return containerSize.height > 0 && containerSize.width > containerSize.height
    }

    /// 右ペインの内容の上端に取る余白（縦バーのポーズではウィンドウ上端を基準にしているため必要）
    private var paneTopMargin: CGFloat {
        isVerticalBarPose ? VerticalBarLayout.edgeMargin : 0
    }

    // MARK: - サブビュー

    /// 2ペイン（左＝時間割、右＝「今日」または科目詳細）。
    ///
    /// `ArrangementView` は折りたたみに合わせて継ぎ目をヒンジに揃えてくれる。
    /// ナビゲーションの入れ物（`NavigationStack`）はこの外側（`ContentView`）にある
    @available(iOS 27.1, *)
    private var twoPaneLayout: some View {
        ArrangementView {
            gridPane
        } secondary: {
            detailPane
        }
        .arrangementViewStyle(.split.axes(.horizontal))
    }

    /// 右ペイン。授業を選んでいればその科目詳細を、選んでいなければ「今日」を出す
    private var detailPane: some View {
        TimetableDetailPane(
            viewModel: viewModel,
            selection: $selection,
            presetColors: presetColors,
            isVerticalBarPose: isVerticalBarPose,
            paneTopMargin: paneTopMargin,
            gridMetrics: gridMetrics,
            onOpenBus: onOpenBus,
            onOpenAssignments: onOpenAssignments
        )
    }

    /// 左ペイン（1ペインのときはページ全体）。タイトルと時間割の表
    private var gridPane: some View {
        GeometryReader { geometry in
            // Layout constants
            let layout = LayoutMetrics(
                geometry: geometry,
                columnCount: viewModel.getWeekdays().count,
                rowCount: viewModel.getPeriods().count,
                isVerticalBarPose: isVerticalBarPose
            )

            VStack(spacing: 0) {
                if isVerticalBarPose {
                    // 縦バーのポーズではバーのタイトルを消し、同じ見た目のタイトルをここに描く。
                    // グリフ上端がウィンドウ上端から VerticalBarLayout.edgeMargin の位置に来る
                    VerticalBarPageTitle(title: title)
                        .padding(.bottom, layout.titleBottomSpacing)
                }

                contentView(layout: layout)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .edgesIgnoringSafeArea(.bottom)
            // 解けた行の寸法を右ペインへ渡す（右ペインで計算し直さないための唯一の経路）
            .onChange(of: layout.gridMetrics, initial: true) {
                _, metrics in
                gridMetrics = metrics
            }
        }
    }

    /// タイトルの下に置く本体（エラー・時間割）。
    ///
    /// 最初の読み込み中も表の枠（曜日の行と時限の列）はそのまま描き、セルだけをスケルトンにする。
    /// エラーと表の入れ替わりはフェードでつなぐ
    @ViewBuilder private func contentView(layout: LayoutMetrics) -> some View {
        ZStack(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
                    .motionTransition(.fade)
            } else {
                VStack(spacing: 0) {
                    weekdayHeaderView(layout: layout)
                    timeTableGridView(layout: layout)
                }
                .motionTransition(.fade)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .motionAnimation(Motion.standard, value: viewModel.errorMessage != nil)
        .padding(.leading, layout.leftPadding)
        .padding(.trailing, layout.rightPadding)
        .padding(.top, layout.topPadding)
        // 最初の読み込みが終わったら、スケルトンから本物のセルへ全体を1回だけクロスフェードで入れ替える。
        // 最初のフレームからセルを出せるとき（表示した時点で読み込み済み）は動かさずにそのまま出す
        .onChange(of: viewModel.hasLoadedOnce, initial: true) { wasLoaded, loaded in
            guard loaded && !hasRevealedCells else { return }
            if wasLoaded {
                // 最初の呼び出し（initial）の時点ですでに読み込み済み＝スケルトンは見せていない
                hasRevealedCells = true
            } else {
                withMotion(Motion.standard) {
                    hasRevealedCells = true
                }
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack {
            Text("エラーが発生しました")
                .font(.headline)
                .padding(.bottom, 8)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("再読み込み") {
                // データを再取得
                viewModel.fetchTimetableData()
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func weekdayHeaderView(layout: LayoutMetrics) -> some View {
        HStack(spacing: LayoutMetrics.cellSpacing) {
            Text("")
                .frame(width: layout.timeColumnWidth)

            ForEach(viewModel.getWeekdays(), id: \.self) { day in
                if day == viewModel.getCurrentWeekday() {
                    currentDayView(day: day, width: layout.cellWidth, height: layout.weekdayRowHeight)
                } else {
                    Text(weekdayString(from: day))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary)
                        .frame(width: layout.cellWidth, height: layout.weekdayRowHeight)
                }
            }
        }
        .frame(height: layout.weekdayRowHeight)
        .padding(.bottom, layout.weekdayBottomSpacing)
    }

    private func currentDayView(day: String, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 20, height: 20)
            Text(weekdayString(from: day))
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
        .frame(width: width, height: height)
    }

    /// 時間割の表。
    ///
    /// 時限の列とセルの束を左右に分けて組む（行の高さはどちらも `cellHeight` なので、行ごとに組んだときと同じ見た目）。
    /// 分けてあるのは、スケルトンのきらめきをセルの束だけに1回掛け、時限の列は読み込み中も読めるようにするため
    private func timeTableGridView(layout: LayoutMetrics) -> some View {
        let periods = viewModel.getPeriods()
        return HStack(alignment: .top, spacing: LayoutMetrics.cellSpacing) {
            VStack(spacing: LayoutMetrics.cellSpacing) {
                ForEach(periods, id: \.0) { period, startTime, endTime in
                    timeColumnView(
                        period: period, startTime: startTime, endTime: endTime, layout: layout)
                }
            }

            VStack(spacing: LayoutMetrics.cellSpacing) {
                ForEach(periods, id: \.0) { period, _, _ in
                    periodRowView(period: period, layout: layout)
                }
            }
            // セルのスケルトンは読み込み後の空きセルと同じ見た目にしたいので、中身は薄めない
            .skeleton(!hasRevealedCells, contentOpacity: 1)
        }
        // 読み込み後の更新（前面復帰・再取得など）で表の中身や行数が変わっても動かさない。
        // データが届いただけで表が揺れたり薄れたりしないよう、ここにはアニメーションを付けない
    }

    private func timeColumnView(
        period: String, startTime: String, endTime: String, layout: LayoutMetrics
    ) -> some View {
        VStack(spacing: 2) {
            Text(startTime)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            Text(period)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(endTime)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
        .frame(width: layout.timeColumnWidth, height: layout.cellHeight)
    }

    private func periodRowView(period: String, layout: LayoutMetrics) -> some View {
        let weekdays = viewModel.getWeekdays()
        return HStack(spacing: LayoutMetrics.cellSpacing) {
            ForEach(weekdays, id: \.self) { day in
                TimeSlotCell(
                    dayIndex: day,
                    displayDay: weekdayString(from: day),
                    period: period,
                    course: viewModel.courses[day]?[period],
                    presetColors: presetColors,
                    cellWidth: layout.cellWidth,
                    cellHeight: layout.cellHeight,
                    onColorChange: { colorIndex in
                        viewModel.updateCourseColor(
                            day: day, period: period, colorIndex: colorIndex)
                    },
                    isCurrentDay: day == viewModel.getCurrentWeekday(),
                    isCurrentPeriod: period == viewModel.getCurrentPeriod(),
                    isSelected: selection == CourseSelection(day: day, period: period),
                    // 2ペインのときは右ペインへ出すので、セルからシートは出さない
                    onSelect: isTwoPane
                        ? {
                            withMotion(Motion.standard) {
                                selection = CourseSelection(day: day, period: period)
                            }
                        }
                        : nil
                )
                .modifier(
                    CellReveal(
                        isRevealed: hasRevealedCells,
                        width: layout.cellWidth, height: layout.cellHeight))
            }
        }
    }

    // MARK: - DEBUG用の選択

    #if DEBUG
    /// 自動選択をやり直す必要があるかを見るための値
    private var debugSelectionTrigger: DebugSelectionTrigger {
        DebugSelectionTrigger(isTwoPane: isTwoPane, courseCount: viewModel.getTotalCourseCount())
    }

    private struct DebugSelectionTrigger: Equatable {
        let isTwoPane: Bool
        let courseCount: Int
    }

    /// 起動引数 `-DuoSelectFirstCourse YES` が指定されていれば、最初の授業を選んでおく。
    /// CLIからはセルをタップできないため、科目詳細の状態を撮るための入口として用意している
    private func applyDebugSelectionIfNeeded() {
        guard isTwoPane, selection == nil else { return }
        // `-DuoSelectTodayPeriod 2` …「今日」ペインの「詳細」を押したのと同じ選択をする
        if let period = DuoDebugTimetable.selectedTodayPeriod {
            let day = DuoDebugTimetable.todayWeekday ?? viewModel.getCurrentWeekday()
            selection = CourseSelection(day: day, period: period)
            return
        }
        guard DuoDebugTimetable.selectsFirstCourse else { return }
        for period in viewModel.getPeriods().map({ $0.0 }) {
            for day in viewModel.getWeekdays() where viewModel.courses[day]?[period] != nil {
                selection = CourseSelection(day: day, period: period)
                return
            }
        }
    }
    #endif
}

// MARK: - レイアウト定数
private struct LayoutMetrics {

    /// 縦バーのポーズでウィンドウの上端・下端に残すマージン（上下で同じ値を使う）。
    /// 一番上のコンテンツ（タイトル）の上と、グリッド最下段の下の両方にこの余白を取る
    private static let verticalBarEdgeMargin = VerticalBarLayout.edgeMargin

    /// 縦バーのポーズでの、タイトルのグリフ下端から曜日のグリフ上端までの間隔
    private static let verticalBarTitleGlyphGap: CGFloat = 10

    /// 曜日の文字（14pt）が曜日行の枠（`weekdayRowHeight`）から上下にはみ出す量。
    /// 枠より文字の方が高く、中央揃えで描かれるため、グリフ上端は枠の上端より少し上に出る
    private static let weekdayGlyphOverhang: CGFloat = 0.9

    /// 縦バーのポーズでの曜日行とグリッドの間隔。
    /// 上へ詰める分、タイトル・曜日行・1行目が窮屈にならないよう通常より狭くする
    private static let verticalBarWeekdayBottomSpacing: CGFloat = 10

    /// 上余白の既定値（横バーのポーズでは従来どおりこの値を使う）
    private static let defaultTopPadding: CGFloat = 8

    /// 曜日行とグリッドの間隔の既定値
    private static let defaultWeekdayBottomSpacing: CGFloat = 16

    /// 高さの計算で差し引く固定分。上余白＋曜日行＋その下の余白より少し大きく、
    /// 差分がグリッド下端の余りになる（従来からの値で、横バーのポーズでは変更しない）
    private static let reservedHeight: CGFloat = 40

    /// セルとセルの間隔（縦横とも同じ値）
    static let cellSpacing: CGFloat = 4

    /// 曜日の文字の大きさ
    static let weekdayFontSize: CGFloat = 14

    let timeColumnWidth: CGFloat = 35
    let leftPadding: CGFloat = 8
    let rightPadding: CGFloat = 10
    let weekdayRowHeight: CGFloat = 10
    let weekdayBottomSpacing: CGFloat
    let topPadding: CGFloat
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    /// ページ内タイトルの下に空ける余白（横バーのポーズでは使わない）
    let titleBottomSpacing: CGFloat

    /// ペインの上端から曜日の行の上端までの距離
    let weekdayRowTop: CGFloat

    /// ペインの上端から1行目のセルの上端までの距離
    var gridTop: CGFloat { weekdayRowTop + weekdayRowHeight + weekdayBottomSpacing }

    /// 表そのものの高さ（1行目のセルの上端から最終行のセルの下端まで）
    let gridHeight: CGFloat

    /// 右ペインへ渡す縦の目盛り（見出しの帯・1行目のセルの上端・セルどうしの間隔を共有する）
    var gridMetrics: TimetableGridMetrics {
        // ArrangementView がペインを組み替えている途中は GeometryReader が一時的に
        // 0 に近い大きさを受け取る。その間の目盛りを右ペインへ渡すと、右側も
        // 未確定の高さで組まれてしまうため、次の有効なレイアウトまで描画を待たせる
        guard cellWidth > 0, cellHeight > 0, gridHeight > 0 else { return .unavailable }

        return TimetableGridMetrics(
            gridTop: gridTop,
            weekdayRowTop: weekdayRowTop,
            weekdayRowHeight: weekdayRowHeight,
            weekdayFontSize: Self.weekdayFontSize,
            rowGap: Self.cellSpacing,
            gridHeight: gridHeight)
    }

    init(geometry: GeometryProxy, columnCount: Int, rowCount: Int, isVerticalBarPose: Bool) {
        let safeColumnCount = max(1, columnCount)
        let safeRowCount = max(1, rowCount)
        let columnGapWidth = CGFloat(safeColumnCount - 1) * Self.cellSpacing
        let rowGapHeight = CGFloat(safeRowCount - 1) * Self.cellSpacing

        let proposedCellWidth =
            (geometry.size.width - timeColumnWidth - leftPadding - rightPadding - columnGapWidth)
            / CGFloat(safeColumnCount)
        cellWidth = Self.validDimension(proposedCellWidth)

        if isVerticalBarPose {
            // 縦バーのポーズでは上下のセーフエリアを無視しているので、geometry の上下端＝ウィンドウの上下端。
            // 上端から verticalBarEdgeMargin の位置にタイトルのグリフ上端を、
            // 下端から同じ量だけ上にグリッドの最下段を置き、残りをグリッドに割り付ける
            weekdayBottomSpacing = Self.verticalBarWeekdayBottomSpacing
            topPadding = 0

            // タイトルが占める高さ：グリフ上端までの余白 ＋ 行の高さ ＋ 曜日行との間隔
            titleBottomSpacing =
                Self.verticalBarTitleGlyphGap - VerticalBarPageTitle.glyphBottomInset
                + Self.weekdayGlyphOverhang
            let titleBlockHeight =
                Self.verticalBarEdgeMargin - VerticalBarPageTitle.glyphTopInset
                + VerticalBarPageTitle.lineHeight + titleBottomSpacing

            let proposedGridHeight =
                geometry.size.height - Self.verticalBarEdgeMargin - titleBlockHeight
                - topPadding - weekdayRowHeight - weekdayBottomSpacing
            let proposedCellHeight =
                (proposedGridHeight - rowGapHeight) / CGFloat(safeRowCount)
            cellHeight = Self.validDimension(proposedCellHeight)
            weekdayRowTop = titleBlockHeight + topPadding
            gridHeight = Self.resolvedGridHeight(
                cellHeight: cellHeight, rowCount: safeRowCount, rowGapHeight: rowGapHeight)
        } else {
            // 横バーのポーズは従来どおり（式を変えない）
            weekdayBottomSpacing = Self.defaultWeekdayBottomSpacing
            topPadding = Self.defaultTopPadding
            titleBottomSpacing = 0
            let proposedCellHeight =
                (geometry.size.height - Self.reservedHeight
                    - rowGapHeight) / CGFloat(safeRowCount)
            cellHeight = Self.validDimension(proposedCellHeight)
            weekdayRowTop = topPadding
            gridHeight = Self.resolvedGridHeight(
                cellHeight: cellHeight, rowCount: safeRowCount, rowGapHeight: rowGapHeight)
        }
    }

    /// SwiftUI の固定 frame に渡せる、有限かつ 0 以上の寸法にする。
    /// ペイン切り替え中の一時的な負数は 0 として扱い、次のレイアウトで実寸に戻す
    private static func validDimension(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    /// セルの高さから実際に描かれる表全体の高さを戻す。
    /// セルを置けない過渡状態では 0 にして、右ペインには未確定として伝える
    private static func resolvedGridHeight(
        cellHeight: CGFloat, rowCount: Int, rowGapHeight: CGFloat
    ) -> CGFloat {
        guard cellHeight > 0 else { return 0 }
        return cellHeight * CGFloat(rowCount) + rowGapHeight
    }
}

// MARK: - セルの登場

/// 最初の読み込みが終わったときに、スケルトン（空きセルの形）から本物のセルへ入れ替える。
///
/// スケルトンとセルを重ねておき、不透明度だけを入れ替える（間に何も無い瞬間を作らない）。
/// 全部のセルが同時に入れ替わる（列ごとに遅らせない）。動かすかどうかと速さは、
/// `isRevealed` を変える側（`withMotion(Motion.standard)`、スケルトンを見せていたときだけ）が決める
private struct CellReveal: ViewModifier {
    let isRevealed: Bool
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .background {
                EmptyCellSkeleton(width: width, height: height)
                    .opacity(isRevealed ? 0 : 1)
            }
    }
}

/// 読み込み中のセル。読み込み後の空きセル（地の色＋1pt の区切り線の枠）とほぼ同じもので、
/// 気づくか気づかないか程度の `Color.primary` 2% を重ねただけ。
///
/// 読み込み中であることは、上を流れる光の帯（`skeleton(_:)` のきらめき）だけで伝える。
/// 本物のセルへ入れ替わっても見た目はほとんど変わらない
private struct EmptyCellSkeleton: View {
    let width: CGFloat
    let height: CGFloat

    /// 地の色に重ねるごく薄い色の濃さ
    private static let tintOpacity: Double = 0.02

    var body: some View {
        // 角の形・地の色・枠は `TimeSlotCell` の空きセルと揃える
        RoundedRectangle(cornerRadius: TimeSlotCell.cornerRadius)
            .fill(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: TimeSlotCell.cornerRadius)
                    .fill(Color.primary.opacity(Self.tintOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimeSlotCell.cornerRadius)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - セルを押したときの沈み込み

/// 押しているあいだセルを少しだけ縮める（跳ねない）。
/// 「視差効果を減らす」が有効なら縮めずに、わずかに薄くするだけにする
private struct CellPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CellPressBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct CellPressBody<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 押しているあいだの縮み具合
    private static var pressedScale: CGFloat { 0.97 }

    /// 「視差効果を減らす」が有効なときの、押しているあいだの不透明度
    private static var pressedOpacity: Double { 0.8 }

    var body: some View {
        label
            .scaleEffect(isPressed && !reduceMotion ? Self.pressedScale : 1)
            .opacity(isPressed && reduceMotion ? Self.pressedOpacity : 1)
            .motionAnimation(Motion.quick, value: isPressed)
    }
}

// MARK: - 科目詳細へのズーム

/// セルから科目詳細のシートへズームでつなぐ（iOS 18 以降）。iOS 17 では通常のシートのまま
private struct ZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct ZoomDestination: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

// MARK: - 時限セル
/// 授業セルビュー
struct TimeSlotCell: View {
    /// セルの角丸。右ペインのカードもこの値に揃える
    static let cornerRadius: CGFloat = 8

    let dayIndex: String
    let displayDay: String
    let period: String
    let course: CourseModel?
    let presetColors: [Color]
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onColorChange: (Int) -> Void

    // 現在の時限かどうかを判断するプロパティを追加
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool

    /// 右ペインに出している授業かどうか（2ペインのときだけ true になりうる）
    var isSelected = false

    /// セルを押したときの処理。nil なら従来どおりシートで科目詳細を出す
    var onSelect: (() -> Void)?

    @State private var showingDetail = false

    /// セルを押した回数（選択の触覚を返すきっかけ）
    @State private var tapCount = 0

    /// シートへズームでつなぐための名前空間（セルごとに1つ）
    @Namespace private var zoomNamespace

    /// ズームの元と先を結ぶ識別子
    private static let zoomID = "course-cell"

    /// 科目に付けた色（セルの塗り）。
    ///
    /// 先頭のプリセット（＝色を付けていない状態）だけは、固定の白ではなくページの地の色にする。
    /// 固定の白のままだと暗い外観で白地に白文字になり、セルが読めなくなるため
    private var courseBackgroundColor: Color {
        guard let course, course.colorIndex != 0,
              presetColors.indices.contains(course.colorIndex)
        else {
            return Color(UIColor.systemBackground)
        }
        return presetColors[course.colorIndex]
    }

    /// セルの枠線の色と太さ（選択中 → 現在の時限 → 通常の順に優先する）
    private var border: (color: Color, width: CGFloat) {
        if isSelected {
            return (.appPrimary, 2)
        }
        if isCurrentDay && isCurrentPeriod {
            return (.green, 1.5)
        }
        return (Color(UIColor.separator), 1)
    }

    var body: some View {
        Group {
            if course != nil {
                Button(action: select) {
                    cellContent
                }
                .buttonStyle(CellPressStyle())
                .modifier(ZoomSource(id: Self.zoomID, namespace: zoomNamespace))
                .selectionHaptic(trigger: tapCount)
            } else {
                cellContent
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let course = course {
                CourseDetailView(
                    course: course,
                    presetColors: presetColors,
                    selectedColorIndex: course.colorIndex,
                    onColorChange: onColorChange
                )
                .modifier(ZoomDestination(id: Self.zoomID, namespace: zoomNamespace))
            }
        }
    }

    /// セルを押したとき（2ペインなら右ペインへ、1ペインならシートで科目詳細を出す）
    private func select() {
        guard course != nil else { return }
        if let onSelect {
            // 選び済みのセルをもう一度押しただけのときは触覚を返さない
            if !isSelected { tapCount += 1 }
            onSelect()
        } else {
            tapCount += 1
            showingDetail = true
        }
    }

    private var cellContent: some View {
        ZStack {
            // 背景色
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(courseBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cornerRadius)
                        .stroke(border.color, lineWidth: border.width)
                )
                // 選択の枠は小さな状態の切り替えなので素早く動かす
                .motionAnimation(Motion.quick, value: isSelected)

            if let course = course {
                // 授業情報テキスト
                VStack(spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.primary)
                    Text(course.room)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 4)

                // 未読掲示
                if let keijiMidokCnt = course.keijiMidokCnt, keijiMidokCnt > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 15, height: 15)
                                Text("\(keijiMidokCnt)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.trailing, -6)
                            .padding(.top, -6)
                        }
                        Spacer()
                    }
                    .padding(4)
                    .frame(width: cellWidth, height: cellHeight)
                }
            } else {
                // 空セルテキスト
                Text("\(displayDay)\(period)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

#Preview {
    TimetableViewPreviewHost()
        .environmentObject(RatingService.shared)
        .environmentObject(GoogleOAuthService.shared)
}

private struct TimetableViewPreviewHost: View {
    @State private var selectedTab = 1
    @State private var isLoggedIn = true

    private var title: String { Semester.current.fullDisplayName }

    var body: some View {
        TabView(selection: $selectedTab) {
            Color.clear
                .tabItem {
                    Label(NSLocalizedString("バス", comment: "タブバー"), systemImage: "bus")
                }
                .tag(0)

            NavigationStack {
                TimetableView(isLoggedIn: $isLoggedIn, title: title, isVerticalBarPose: false)
                    .navigationTitle(title)
                    .toolbarTitleDisplayMode(.inline)
                    .mainToolbar(title: title, isVerticalBarPose: false, isLoggedIn: $isLoggedIn)
            }
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
