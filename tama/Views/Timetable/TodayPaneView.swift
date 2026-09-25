import SwiftUI

// MARK: - 「今日」ペイン

/// 2ペイン表示（iPhone Duoの内側ディスプレイ・横向き）で右側に出す「今日」のページ。
///
/// 組み方は**弁当箱**。4枚のタイルがそれぞれ決まった場所に決まった形で在る:
///
/// ```
/// [ ①授業（いま／次）                 ]
/// [ ②このあとの授業（無ければ出さない） ]
/// [ ③バス ][ ④課題 ]
/// ```
///
/// この並びは時刻で入れ替わらない。朝でも放課後でも「上は授業・左下はバス・右下は課題」なので、
/// 利用者は毎回どこに何があるかを読み直さなくていい。
/// 科目の色はこのペインでは一切使わず、差し色は見出しの記号とタイルの要の数字にだけ入れる。
/// 地は `systemBackground`、タイルは同じ地＋1ptの枠（影なし）でアプリ共通の決まりに従う。
/// 左ペインに揃えるのは見出しの帯・最初のタイルの上端（`gridTop`）・タイルどうしの間隔
/// （＝セルどうしの間隔）の3つ。
///
/// 出どころ:
/// - 授業は左ペインと同じ `TimetableViewModel.courses`
/// - バスは `BusScheduleService` のキャッシュ（12時間より古いときはダミーなので使わない）
/// - 課題は課題タブと共通の `AssignmentStore`（10分に1回まで。この画面のために増やさない）
/// - 掲示だけ `CourseNoticeStore` が授業ごとに1回取りに行き、30分ほど控える
///
/// 時刻に依存する部分（見出しの日付を含む）は `TimelineView(.everyMinute)` で分の変わり目ちょうどに描き直す。
/// 日付もこの時計から求めるので、日付が変わればそのまま翌日の中身になる。
/// 残り10分を切った数字だけはシステム側が秒まで描き直す
struct TodayPaneView: View {

    // MARK: - プロパティ

    /// 時間割の全曜日の授業（曜日キー → 時限キー → 授業）。今日の分はペインの時計の日付で取り出す
    let courses: [String: [String: CourseModel]]

    /// `TimetableViewModel.getPeriods()` が返す（時限, 開始, 終了）の一覧
    let periods: [(String, String, String)]

    /// システムのバーが縦バーとして表示されているか（見出しの上端の取り方が変わる）
    let isVerticalBarPose: Bool

    /// 左ペインが解いた時間割の縦の目盛り
    let metrics: TimetableGridMetrics

    /// 授業を選んだとき（時限のキーを渡す。左ペインのセルを押したときと同じ扱いになる）
    let onSelect: (String) -> Void

    /// バスを選んだとき（バスタブへ切り替え、その路線を選んだ状態にする）
    let onOpenBus: (BusSchedule.RouteType) -> Void

    /// 課題の一覧へ（課題タブへ切り替える）
    let onOpenAssignments: () -> Void

    // どれもアプリ全体で共有しているシングルトンなので、このビューは持ち主にならず見ているだけにする
    @ObservedObject private var selectionStore = BusSelectionStore.shared
    @ObservedObject private var presence = CampusPresenceService.shared
    @ObservedObject private var noticeStore = CourseNoticeStore.shared
    @ObservedObject private var assignmentStore = AssignmentStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Safariで開いている掲示
    @State private var noticeURL: NoticeLink?

    /// ①のタイルの実測の高さ（②と③④に配る高さを決めるのに使う）
    @State private var lessonHeight: CGFloat = 0

    /// 1分ごとに読み直すバスの時刻表（`BusScheduleService` は変更を知らせないので、時計の刻みで読む）
    @State private var busSchedule: BusScheduleRead?

    /// ペインの時計（DEBUGの時刻差し替えを通す）
    private let clock = TodayClock.current

    private typealias Token = TodayPaneTokens

    // MARK: - ボディ

    var body: some View {
        Group {
            if metrics.isAvailable {
                pane
            } else {
                // 左ペインの大きさが決まるまでは何も描かない（次のフレームで決まる）
                Color.clear
            }
        }
        .onAppear {
            presence.start()
            refresh(at: clock.now(Date()))
            assignmentStore.loadIfNeeded()
        }
        .onDisappear(perform: presence.stop)
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            refresh(at: clock.now(Date()))
            assignmentStore.loadIfNeeded()
        }
        .sheet(item: $noticeURL) { link in
            SafariWebView(url: link.url, dismissNotification: .announcementSafariDismissed)
        }
    }

    private var pane: some View {
        // 分の変わり目ちょうどに描き直す（`.periodic(from: .now, by: 60)` だと開いた秒数だけずれる）
        TimelineView(.everyMinute) { context in
            let now = clock.now(context.date)
            let classes = TodaySchedule.todayClasses(on: now, courses: courses, periods: periods)

            VStack(spacing: 0) {
                TodayPaneHeader(date: now, isVerticalBarPose: isVerticalBarPose, metrics: metrics)
                    .frame(height: metrics.gridTop, alignment: .top)

                content(board: board(now: now, classes: classes), classes: classes)
                    // タイルの束は左の表とまったく同じ高さに収める（めくらない）
                    .frame(height: metrics.gridHeight, alignment: .top)
            }
            // 刻みごとに、発車した選択を片付けて時刻表を読み直す
            .onChange(of: context.date) { _, date in
                refresh(at: clock.now(date))
            }
        }
        .padding(.horizontal, Token.Metrics.horizontalInset)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 時計が進んだとき（と、表示・前面に戻ったとき）の片付け。
    /// 発車時刻を過ぎた選択を捨て（学校行きなら発車を記録する）、バスの時刻表を読み直す
    private func refresh(at now: Date) {
        selectionStore.pruneIfPassed(now: now)
        busSchedule = BusScheduleRead(schedule: Self.readBusSchedule())
    }

    // MARK: - 中身

    /// 4枚のタイル。左の表とまったく同じ高さにぴったり収める（めくらない）。
    ///
    /// 高さの配り方は `TodayStackLayout` が数として決める。
    /// ①は中身の高さのまま（測った値を渡す）、②はもらった高さに行を等分して敷き、
    /// ③④は残り全部を受け取って、入るだけ一覧の行を並べる。
    /// 縦積みで1行も入らないタイルは出さない（左の表の下端からはみ出さないため）
    private func content(board: TodayBoard, classes: [TodayClass]) -> some View {
        let layout = self.layout(for: board)

        return VStack(spacing: metrics.rowGap) {
            TodayLessonTile(
                model: board.lesson,
                extraSpacing: layout.lessonExtra,
                onSelect: onSelect,
                onOpenNotice: open(notice:period:))
                .modifier(
                    NoticeLoader(
                        lesson: noticeLesson(for: board.lesson, in: classes), store: noticeStore))
                // 測るのは「足した高さを除いた」①の素の高さ。
                // 足したぶんを引かずに入れ直すと、割り付けと測定が互いを追いかけてしまう
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measured in
                    let base = (measured - layout.lessonExtra).rounded()
                    if abs(base - lessonHeight) >= 1 { lessonHeight = base }
                }

            if let upcoming = board.upcoming {
                TodayUpcomingTile(
                    model: upcoming, limit: layout.upcomingRows,
                    rowHeight: layout.rowHeight, onSelect: onSelect)
            }

            if layout.arrangement.isSideBySide {
                HStack(alignment: .top, spacing: metrics.rowGap) {
                    bus(board, layout: layout)
                    assignments(board, layout: layout)
                }
                // 下の段が残りの高さをすべて受け取る（端数もここで吸い切る）
                .frame(maxHeight: .infinity)
            } else {
                // バスは中身の高さのままの帯にして、残りは課題が取る
                if layout.busRows > 0 {
                    bus(board, layout: layout)
                }
                if layout.assignmentRows > 0 {
                    assignments(board, layout: layout)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: board)
    }

    private func bus(_ board: TodayBoard, layout: TodayStackLayout.Result) -> some View {
        TodayBusTile(
            model: board.bus,
            fillsHeight: layout.arrangement.isSideBySide,
            rows: layout.busRows,
            rowHeight: layout.rowHeight,
            onOpenBus: onOpenBus)
    }

    private func assignments(
        _ board: TodayBoard, layout: TodayStackLayout.Result
    ) -> some View {
        TodayAssignmentTile(
            model: board.assignments,
            rows: layout.assignmentRows,
            rowHeight: layout.rowHeight,
            sharesFreeHeight: layout.arrangement == .stacked,
            onOpenAssignment: open(assignment:),
            onOpenAssignments: onOpenAssignments)
    }

    /// その盤面の高さの割り付け
    private func layout(for board: TodayBoard) -> TodayStackLayout.Result {
        TodayStackLayout.solve(
            total: metrics.gridHeight,
            gap: metrics.rowGap,
            lessonHeight: lessonHeight > 0 ? lessonHeight : Self.estimatedLessonHeight,
            upcomingCount: board.upcoming?.rows.count ?? 0,
            busCount: max(1, board.bus.rows.count),
            assignmentCount: max(1, board.assignments.items.count))
    }

    /// ①をまだ測れていないときの目安（次のフレームで実測に置き換わる）
    private static let estimatedLessonHeight: CGFloat = 176

    /// その時刻の4枚のタイルを組み立てる
    private func board(now: Date, classes: [TodayClass]) -> TodayBoard {
        TodayBoardBuilder.make(
            state: TodayPhaseEngine.state(for: input(now: now, classes: classes)),
            classes: classes,
            assignments: assignmentStore.assignments,
            now: now,
            clock: clock,
            roomChange: Self.roomChange(for:),
            notice: { noticeStore.notices(for: $0) ?? [] },
            hasLoadedAssignments: assignmentStore.hasLoadedOnce)
    }

    // MARK: - 入力の組み立て

    private func input(now: Date, classes: [TodayClass]) -> TodayPaneInput {
        TodayPaneInput(
            now: now,
            classes: classes,
            bus: busSnapshot(now: now),
            station: selectionStore.preferredStation,
            selection: selectionStore.selectedDeparture,
            isOnCampus: isOnCampus,
            hasDepartedTowardSchool: selectionStore.hasDepartedTowardSchool(on: now)
        )
    }

    /// 今日のバス時刻表（刻みごとに読んだ控えから作る。まだ読んでいなければその場で1回だけ読む）
    private func busSnapshot(now: Date) -> BusSnapshot {
        BusSnapshot.make(
            schedule: (busSchedule ?? BusScheduleRead(schedule: Self.readBusSchedule())).schedule,
            weekday: TodaySchedule.calendarWeekday(for: now),
            referenceDate: now)
    }

    /// バスの時刻表を読む。12時間より古いキャッシュしか無いときはダミーが返るので使わない
    private static func readBusSchedule() -> BusSchedule? {
        var schedule: BusSchedule?
        if BusScheduleService.shared.isCacheValid() {
            schedule = BusScheduleService.shared.getBusScheduleData()
        }
        #if DEBUG
        if schedule == nil, DuoDebugTimetable.usesMockDay {
            schedule = DuoDebugTimetable.mockBusSchedule()
        }
        #endif
        return schedule
    }

    /// 学内に居るか（DEBUGの差し替えがあればそれを使う）
    private var isOnCampus: Bool? {
        #if DEBUG
        if let overridden = DuoDebugTimetable.onCampusOverride { return overridden }
        #endif
        return presence.isOnCampus
    }

    /// 教室変更（DEBUGのモックの1日では差し替える）
    private static func roomChange(for course: CourseModel) -> RoomChange? {
        #if DEBUG
        if DuoDebugTimetable.usesMockDay {
            return DuoDebugTimetable.mockRoomChange(forCourseNamed: course.name)
        }
        #endif
        return TimetableService.shared.roomChange(forCourseNamed: course.name)
    }

    // MARK: - 掲示

    /// 掲示を取りに行く対象の授業（①のタイルが授業を映しているあいだだけ）
    private func noticeLesson(for tile: TodayLessonTileModel, in classes: [TodayClass]) -> TodayClass? {
        guard let period = tile.period else { return nil }
        return classes.first { $0.period == period }
    }

    /// 「掲示」を押したとき。
    /// 題名が取れていればその掲示を科目詳細とまったく同じURLで開き、
    /// まだ取れていなければ科目詳細そのものを右ペインに出す
    private func open(notice: TodayNotice?, period: String) {
        guard let notice,
              let url = TNextWebLink.announcementURL(
                keijiNo: notice.id, torkDate: notice.torkDate)
        else {
            onSelect(period)
            return
        }
        noticeURL = NoticeLink(url: url)
    }

    // MARK: - 課題

    /// 課題タブ（`AssignmentViewModel.openAssignmentURL`）と同じ開き方にする
    private func open(assignment urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 読んだバスの時刻表

/// 刻みごとに読んだバスの時刻表（読んだが使えなかった＝nil と、まだ読んでいないを分けるための包み）
private struct BusScheduleRead {
    let schedule: BusSchedule?
}

// MARK: - Safariで開く掲示

/// `sheet(item:)` に渡すためのURLの包み
private struct NoticeLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - 掲示の取得

/// ①のタイルが授業を映しているあいだに、その授業の掲示を1回だけ取りに行く。
///
/// 題名が取れるかどうかで「掲示」ボタンの行き先が変わるため、取得のきっかけは
/// 必ず出ているタイルに付けておく（`TimelineView` の1分ごとの描き直しでは取り直さない）
private struct NoticeLoader: ViewModifier {

    let lesson: TodayClass?
    let store: CourseNoticeStore

    func body(content: Content) -> some View {
        content.task(id: lesson?.id) {
            guard let lesson else { return }
            store.loadIfNeeded(for: lesson.course)
        }
    }
}

// MARK: - 見出し

/// ペインの見出し（左ペインのタイトル＋曜日行の帯とまったく同じ高さ・同じ横線、ただし末尾寄せ）。
///
/// 左ペインの学期名が先頭側の端に揃うのに対して、右ペインの見出しは末尾側＝縦バー側の端に揃え、
/// 下に並ぶ内容と同じ末尾の余白（`TodayPaneTokens.Metrics.horizontalInset`）で止める。
/// 日付の行は左ペインの曜日の行と同じ中心線に乗るので、2つのペインは横線も共有する。
/// 寄せは `leading` / `trailing` の意味で指定しているので、RTLでも自動的に反転する
private struct TodayPaneHeader: View {

    let date: Date
    let isVerticalBarPose: Bool
    let metrics: TimetableGridMetrics

    /// タイトルの行が占める高さ（グリフ上端までの余白＋行の高さ）
    private var titleHeight: CGFloat {
        glyphTopMargin - VerticalBarPageTitle.glyphTopInset + VerticalBarPageTitle.lineHeight
    }

    private var glyphTopMargin: CGFloat {
        isVerticalBarPose ? VerticalBarLayout.edgeMargin : TodayPaneTokens.Spacing.xSmall
    }

    var body: some View {
        VStack(spacing: 0) {
            VerticalBarPageTitle(
                title: NSLocalizedString("今日", comment: "「今日」ペインの見出し"),
                glyphTopMargin: glyphTopMargin,
                edge: .trailing,
                sideMargin: 0
            )

            Color.clear.frame(height: max(0, metrics.weekdayRowTop - titleHeight))

            Text(date.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.system(size: metrics.weekdayFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                // 曜日行の枠（10pt）は文字より低く、左ペインの曜日も上下にはみ出して描いている。
                // 縮小を許すと枠の高さに合わせて文字が小さくなるので、文字の大きさは固定して同じようにはみ出させる
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: metrics.weekdayRowHeight)
        }
    }
}

// MARK: - 時限の表示

/// 時限の表示（「3限」）。表記はローカライズ側で切り替える
enum PeriodLabel {

    static func text(for periodNumber: Int) -> String {
        String(format: NSLocalizedString("%d限", comment: "時限"), periodNumber)
    }
}
