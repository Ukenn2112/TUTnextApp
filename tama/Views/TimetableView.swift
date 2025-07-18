import SwiftUI

struct TimetableView: View {
    // MARK: - Properties
    @StateObject private var viewModel = TimetableViewModel()
    @Binding var isLoggedIn: Bool  // 添加登录状态绑定
    @Environment(\.colorScheme) private var colorScheme  // 添加这一行
    @EnvironmentObject private var ratingService: RatingService
    // 前台通知观察者
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil
    // 掲示リストSafariView閉じる通知観察者
    @State private var announcementSafariDismissObserver: NSObjectProtocol? = nil

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
            NSLocalizedString("日", comment: ""),
        ]
        return weekdays[idx - 1]
    }

    private let presetColors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),  // 浅粉色
        Color(red: 1.0, green: 0.9, blue: 0.8),  // 浅橙色
        Color(red: 1.0, green: 1.0, blue: 0.8),  // 浅黄色
        Color(red: 0.9, green: 1.0, blue: 0.8),  // 浅绿色
        Color(red: 0.8, green: 1.0, blue: 0.8),  // 绿色
        Color(red: 0.8, green: 1.0, blue: 1.0),  // 青色
        Color(red: 1.0, green: 0.8, blue: 0.9),  // 粉紫色
        Color(red: 0.9, green: 0.8, blue: 1.0),  // 浅紫色
        Color(red: 0.8, green: 0.9, blue: 1.0),  // 浅蓝色
        Color(red: 1.0, green: 0.9, blue: 1.0),  // 浅紫色
    ]

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            // Layout constants
            let layout = LayoutMetrics(
                geometry: geometry,
                columnCount: viewModel.getWeekdays().count,
                rowCount: viewModel.getPeriods().count
            )

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
                            // 刷新数据而不是登出
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
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                viewModel.fetchTimetableData()
                // 時間割表示の重要イベントを記録
                ratingService.recordSignificantEvent()
                // 应用程序从后台恢复时刷新页面
                willEnterForegroundObserver = NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification,
                    object: nil,
                    queue: .main
                ) { [self] _ in
                    print("TimetableView: アプリがフォアグラウンドに復帰しました")
                    viewModel.fetchTimetableData()

                    // 通知設定の状態を確認してサーバーと同期
                    NotificationService.shared.checkAuthorizationStatus()
                    NotificationService.shared.syncNotificationStatusWithServer()
                }

                // 掲示リストのSafariViewが閉じられた時の通知を受け取る
                announcementSafariDismissObserver = NotificationCenter.default.addObserver(
                    forName: .announcementSafariDismissed,
                    object: nil,
                    queue: .main
                ) { [self] _ in
                    print("TimetableView: 掲示リストのSafariViewが閉じられました")
                    viewModel.fetchTimetableData()
                }
            }
            .onDisappear {
                // 移除通知观察者
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
    }

    // MARK: - Subviews
    private func weekdayHeaderView(layout: LayoutMetrics) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: layout.timeColumnWidth)

            ForEach(viewModel.getWeekdays(), id: \.self) { day in
                if day == viewModel.getCurrentWeekday() {
                    currentDayView(day: day, width: layout.cellWidth)
                } else {
                    Text(weekdayString(from: day))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: layout.cellWidth, height: 10)
                }
            }
        }
        .frame(height: 10)
        .padding(.bottom, 16)
    }

    private func currentDayView(day: String, width: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 20, height: 20)
            Text(weekdayString(from: day))
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .frame(width: width, height: 10)
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
                    isLoggedIn: $isLoggedIn,
                    isCurrentDay: day == viewModel.getCurrentWeekday(),
                    isCurrentPeriod: period == viewModel.getCurrentPeriod()
                )
            }
        }
    }
}

// MARK: - Layout Metrics
private struct LayoutMetrics {
    let timeColumnWidth: CGFloat = 35
    let leftPadding: CGFloat = 8
    let rightPadding: CGFloat = 10
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    init(geometry: GeometryProxy, columnCount: Int, rowCount: Int) {
        let safeColumnCount = max(1, columnCount)
        let safeRowCount = max(1, rowCount)

        cellWidth =
            (geometry.size.width - timeColumnWidth - leftPadding - rightPadding - CGFloat(
                safeColumnCount - 1) * 4) / CGFloat(safeColumnCount)
        cellHeight =
            (geometry.size.height - 40 - CGFloat(safeRowCount - 1) * 4) / CGFloat(safeRowCount)
    }
}

// MARK: - TimeSlotCell
// 課程単元格視図
struct TimeSlotCell: View {
    let dayIndex: String
    let displayDay: String
    let period: String
    let course: CourseModel?
    let presetColors: [Color]
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onColorChange: (Int) -> Void
    @Binding var isLoggedIn: Bool  // 添加isLoggedIn绑定
    @Environment(\.colorScheme) private var colorScheme  // 添加这一行

    // 現在の時限かどうかを判断するプロパティを追加
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool

    @State private var showingDetail = false

    // 添加颜色调整的计算属性
    private var adjustedBackgroundColor: Color {
        guard let course = course else {
            return colorScheme == .dark ? Color(UIColor.systemGray6) : .white
        }
        let baseColor = presetColors[course.colorIndex]
        return colorScheme == .dark ? baseColor.opacity(0.8) : baseColor
    }

    var body: some View {
        ZStack {
            // 修改背景色
            RoundedRectangle(cornerRadius: 8)
                .fill(adjustedBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            (isCurrentDay && isCurrentPeriod)
                                ? Color.green
                                : (colorScheme == .dark
                                    ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2)),
                            lineWidth: (isCurrentDay && isCurrentPeriod) ? 1.5 : 1
                        )
                )

            if let course = course {
                // 修改课程信息文字颜色
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
                // 修改空格子文字颜色
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
                    onColorChange: onColorChange,
                    isLoggedIn: $isLoggedIn
                )
            }
        }
    }
}

#Preview {
    TimetableView(isLoggedIn: .constant(true))
}
