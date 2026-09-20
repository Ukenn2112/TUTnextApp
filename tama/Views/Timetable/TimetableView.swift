import SwiftUI

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
    @EnvironmentObject private var ratingService: RatingService
    // フォアグラウンド復帰通知オブザーバー
    @State private var willEnterForegroundObserver: NSObjectProtocol?
    // 掲示リストSafariView閉じる通知オブザーバー
    @State private var announcementSafariDismissObserver: NSObjectProtocol?

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
        // 縦バーのポーズではウィンドウの上端・下端まで内容を広げ、
        // 上下とも VerticalBarLayout.edgeMargin だけ端から離した位置に内容を置く
        // （バーのタイトル帯は mainToolbar 側で消してある）
        .ignoresSafeArea(.container, edges: ignoredEdges)
    }

    /// セーフエリアを無視する辺（縦バーのポーズでのみ上下を無視し、ウィンドウの端を基準にする）
    private var ignoredEdges: Edge.Set {
        isVerticalBarPose ? [.top, .bottom] : []
    }

    // MARK: - サブビュー

    /// タイトルの下に置く本体（読み込み中・エラー・時間割）
    @ViewBuilder private func contentView(layout: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("エラーが発生しました")
                        .font(.headline)
                        .padding(.bottom, 8)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("再読み込み") {
                        // データを再取得
                        viewModel.fetchTimetableData()
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                weekdayHeaderView(layout: layout)
                timeTableGridView(layout: layout)
            }
        }
        .padding(.leading, layout.leftPadding)
        .padding(.trailing, layout.rightPadding)
        .padding(.top, layout.topPadding)
    }
    private func weekdayHeaderView(layout: LayoutMetrics) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: layout.timeColumnWidth)

            ForEach(viewModel.getWeekdays(), id: \.self) { day in
                if day == viewModel.getCurrentWeekday() {
                    currentDayView(day: day, width: layout.cellWidth, height: layout.weekdayRowHeight)
                } else {
                    Text(weekdayString(from: day))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
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
                .foregroundColor(.white)
        }
        .frame(width: width, height: height)
    }

    private func timeTableGridView(layout: LayoutMetrics) -> some View {
        VStack(spacing: 4) {
            ForEach(viewModel.getPeriods(), id: \.0) { period, startTime, endTime in
                HStack(spacing: 4) {
                    timeColumnView(
                        period: period, startTime: startTime, endTime: endTime, layout: layout)
                    periodRowView(period: period, layout: layout)
                }
            }
        }
    }

    private func timeColumnView(
        period: String, startTime: String, endTime: String, layout: LayoutMetrics
    ) -> some View {
        VStack(spacing: 2) {
            Text(startTime)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(period)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(endTime)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: layout.timeColumnWidth, height: layout.cellHeight)
    }

    private func periodRowView(period: String, layout: LayoutMetrics) -> some View {
        HStack(spacing: 4) {
            ForEach(viewModel.getWeekdays(), id: \.self) { day in
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
                    isCurrentPeriod: period == viewModel.getCurrentPeriod()
                )
            }
        }
    }
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

    init(geometry: GeometryProxy, columnCount: Int, rowCount: Int, isVerticalBarPose: Bool) {
        let safeColumnCount = max(1, columnCount)
        let safeRowCount = max(1, rowCount)

        cellWidth =
            (geometry.size.width - timeColumnWidth - leftPadding - rightPadding - CGFloat(
                safeColumnCount - 1) * 4) / CGFloat(safeColumnCount)

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

            let gridHeight =
                geometry.size.height - Self.verticalBarEdgeMargin - titleBlockHeight
                - topPadding - weekdayRowHeight - weekdayBottomSpacing
            cellHeight = (gridHeight - CGFloat(safeRowCount - 1) * 4) / CGFloat(safeRowCount)
        } else {
            // 横バーのポーズは従来どおり（式を変えない）
            weekdayBottomSpacing = Self.defaultWeekdayBottomSpacing
            topPadding = Self.defaultTopPadding
            titleBottomSpacing = 0
            cellHeight =
                (geometry.size.height - Self.reservedHeight - CGFloat(safeRowCount - 1) * 4)
                / CGFloat(safeRowCount)
        }
    }
}

// MARK: - 時限セル
/// 授業セルビュー
struct TimeSlotCell: View {
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

    @State private var showingDetail = false

    private var courseBackgroundColor: Color {
        guard let course = course else { return Color(UIColor.systemBackground) }
        return presetColors[course.colorIndex]
    }

    var body: some View {
        ZStack {
            // 背景色
            RoundedRectangle(cornerRadius: 8)
                .fill(courseBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            (isCurrentDay && isCurrentPeriod)
                                ? Color.green
                                : Color(UIColor.separator),
                            lineWidth: (isCurrentDay && isCurrentPeriod) ? 1.5 : 1
                        )
                )

            if let course = course {
                // 授業情報テキスト
                VStack(spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.primary)
                    Text(course.room)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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
                                    .foregroundColor(.white)
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
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
        .onTapGesture {
            if course != nil {
                showingDetail = true
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
            }
        }
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
