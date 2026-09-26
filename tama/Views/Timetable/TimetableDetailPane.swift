import SwiftUI

// MARK: - 右ペイン

/// 2ペイン表示の右側。授業を選んでいればその科目詳細を、選んでいなければ「今日」を出す。
///
/// 地の色は左の時間割ペインと同じ `systemBackground` にして、2つのペインが1枚のページに見えるようにする。
/// その上に載るカードは、左ペインの時限セルと同じ1ptの細い枠で輪郭を取る（影は使わない）。
/// `TimetableView` を大きくしないよう、ペインの組み立てだけをここへ分けてある
struct TimetableDetailPane: View {

    // MARK: - プロパティ

    @ObservedObject var viewModel: TimetableViewModel

    /// 右ペインに出している授業（nil なら「今日」ペイン）
    @Binding var selection: CourseSelection?

    let presetColors: [Color]

    /// システムのバーが縦バーとして表示されているか
    let isVerticalBarPose: Bool

    /// 縦バーのポーズで内容の上端に取る余白
    let paneTopMargin: CGFloat

    /// 左ペインが解いた時間割の縦の目盛り（「今日」ペインはこれに揃えて組む）
    let gridMetrics: TimetableGridMetrics

    /// バスタブへ切り替える（路線も一緒に切り替える）
    let onOpenBus: (BusSchedule.RouteType) -> Void

    /// 課題タブへ切り替える
    let onOpenAssignments: () -> Void

    // MARK: - ボディ

    var body: some View {
        content
            .background(Color(UIColor.systemBackground))
    }

    /// 「今日」と科目詳細の入れ替え（別の授業への切り替えを含む）はフェードでつなぐ。
    /// 速さは選択を変える側の `withMotion(Motion.standard)` で決める
    private var content: some View {
        ZStack(alignment: .top) {
            pane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var pane: some View {
        if let selection, let course = course(for: selection) {
            CourseDetailView(
                course: course,
                presetColors: presetColors,
                selectedColorIndex: course.colorIndex,
                onColorChange: { colorIndex in
                    viewModel.updateCourseColor(
                        day: selection.day, period: selection.period, colorIndex: colorIndex)
                },
                onInlineClose: {
                    withMotion(Motion.standard) { self.selection = nil }
                }
            )
            // 科目は init でしか渡らないので、別の授業を選んだら作り直す
            .id(selection)
            .safeAreaPadding(.top, paneTopMargin)
            .motionTransition(.fade)
        } else {
            TodayPaneView(
                courses: viewModel.courses,
                periods: viewModel.getPeriods(),
                isPlaceholder: viewModel.isAwaitingFirstLoad,
                isVerticalBarPose: isVerticalBarPose,
                metrics: gridMetrics,
                onSelect: { period in
                    withMotion(Motion.standard) {
                        selection = CourseSelection(day: todayWeekday, period: period)
                    }
                },
                onOpenBus: onOpenBus,
                onOpenAssignments: onOpenAssignments
            )
            .motionTransition(.fade)
        }
    }

    // MARK: - 選んだ授業

    /// 選んだ授業を引く。
    ///
    /// 左のセルから選んだ授業は必ず時間割にあるが、「今日」ペインの「詳細」から選んだ授業は
    /// ペインが持っている今日の授業（DEBUGのモックの1日を含む）から来るので、
    /// 時間割に無ければそちらから引く。引けないと選んだ印だけが付いて詳細が出ない
    private func course(for selection: CourseSelection) -> CourseModel? {
        if let course = viewModel.courses[selection.day]?[selection.period] {
            return course
        }
        guard selection.day == todayWeekday else { return nil }
        return todayClasses.first { $0.period == selection.period }?.course
    }

    // MARK: - 今日の授業

    /// 「今日」ペインが使う曜日（DEBUGの起動引数で差し替えられる）。
    /// 押した時点で求めるので、日付が変わったあとも「今日」の曜日になる
    private var todayWeekday: String {
        TodaySchedule.weekdayKey(for: Date())
    }

    /// 今日の授業一覧（選んだ授業を引くときだけ使う。ペインそのものは自分の時計で求め直す）
    private var todayClasses: [TodayClass] {
        TodaySchedule.todayClasses(
            on: Date(), courses: viewModel.courses, periods: viewModel.getPeriods())
    }
}
