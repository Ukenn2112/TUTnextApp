import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

// MARK: - ActivityAttributes（アプリ側と同一定義を維持すること）

enum ClassPhase: String, Codable, Hashable {
    case upcoming
    case imminent
    case inProgress
    case breakTime
    case finished
}

struct ClassLiveActivityAttributes: ActivityAttributes {
    public typealias ClassActivityState = ContentState

    public struct ContentState: Codable, Hashable {
        var phase: ClassPhase
        var countdownDate: Date

        var courseName: String
        var room: String
        var teacher: String
        var period: Int
        var startDate: Date
        var endDate: Date

        var hasRoomChange: Bool = false
        var newRoom: String?

        var nextCourseName: String?
        var nextCourseRoom: String?
        var nextCourseTeacher: String?
        var nextCoursePeriod: Int?
    }
}

// MARK: - カラー定義

private extension Color {
    static let iosBlue   = Color(red: 0.039, green: 0.518, blue: 1.0)
    static let iosOrange = Color(red: 1.0,   green: 0.624, blue: 0.039)
    static let iosRed    = Color(red: 1.0,   green: 0.271, blue: 0.227)
    static let iosGreen  = Color(red: 0.196, green: 0.843, blue: 0.294)
}

/// フェーズ + 教室変更に基づくアクセントカラー
private func classAccentColor(_ state: ClassLiveActivityAttributes.ContentState) -> Color {
    if state.hasRoomChange && state.phase != .breakTime && state.phase != .finished {
        return .iosRed
    }
    switch state.phase {
    case .breakTime:  return .iosOrange
    case .finished:   return .iosGreen
    default:          return .iosBlue
    }
}

/// カウントダウンタイマー: 期限到達後は "0:00" を表示し正向計時を防ぐ
private struct CountdownTimerText: View {
    let targetDate: Date
    let isStale: Bool

    var body: some View {
        if isStale {
            Text("0:00")
        } else {
            Text(targetDate, style: .timer)
        }
    }
}

// MARK: - ロック画面ビュー

struct ClassLiveActivityLockScreenView: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            contentRows
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - ヘッダー行

    private var headerRow: some View {
        HStack(spacing: 8) {
            Label {
                Text("TUTnext")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            } icon: {
                Image("AppIconImage")
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(.rect(cornerRadius: 4))
            }

            Text("•")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text(phaseStatusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if context.state.phase == .inProgress {
                HStack(spacing: 4) {
                    Circle()
                        .fill(classAccentColor(context.state))
                        .frame(width: 6, height: 6)
                    Text("授業中")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(classAccentColor(context.state))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(classAccentColor(context.state).opacity(0.1))
                .clipShape(.capsule)
            }

            if context.state.hasRoomChange && context.state.phase != .inProgress {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("教室変更")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.iosRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.iosRed.opacity(0.1))
                .clipShape(.capsule)
            }
        }
    }

    private var phaseStatusText: String {
        switch context.state.phase {
        case .upcoming:   return String(localized: "\(context.state.period)限目 準備")
        case .imminent:   return String(localized: "まもなく開始")
        case .inProgress: return String(localized: "\(context.state.period)限目")
        case .breakTime:  return String(localized: "休み時間")
        case .finished:   return String(localized: "本日終了")
        }
    }

    // MARK: - フェーズ別コンテンツ

    @ViewBuilder
    private var contentRows: some View {
        switch context.state.phase {
        case .upcoming:    upcomingContent
        case .imminent:    imminentContent
        case .inProgress:  inProgressContent
        case .breakTime:   breakTimeContent
        case .finished:    finishedContent
        }
    }

    // --- Upcoming ---

    private var upcomingContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.courseName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    if context.state.hasRoomChange, let newRoom = context.state.newRoom {
                        Text(newRoom)
                            .foregroundStyle(Color.iosRed)
                            .fontWeight(.bold)
                    } else {
                        Text(context.state.room)
                    }
                    Text("•")
                    Text(context.state.teacher)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(classAccentColor(context.state))
                    .multilineTextAlignment(.trailing)
                Text("開始まで")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // --- Imminent ---

    private var imminentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(context.state.hasRoomChange ? "教室変更あり！" : "急いで教室へ！")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(classAccentColor(context.state))
                    Text(context.state.hasRoomChange ? (context.state.newRoom ?? context.state.room) : context.state.room)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.courseName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("まもなく開始します")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: context.state.hasRoomChange ? "exclamationmark.triangle.fill" : "figure.walk")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(classAccentColor(context.state).gradient)
            }
            .padding(12)
            .background(classAccentColor(context.state).opacity(0.08))
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    // --- In Progress ---

    private var inProgressContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(context.state.courseName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if context.state.hasRoomChange {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.iosRed)
                                .padding(3)
                                .background(Color.iosRed.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(context.state.room) • \(context.state.teacher)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.iosBlue)
                        .multilineTextAlignment(.trailing)
                    Text("残り時間")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            progressBar
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: false
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Color.iosBlue)

            HStack {
                Text(context.state.startDate, format: .dateTime.hour().minute())
                Spacer()
                Text(context.state.endDate, format: .dateTime.hour().minute())
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
    }

    // --- Break Time ---

    private var breakTimeContent: some View {
        let nextName = context.state.nextCourseName ?? String(localized: "次の授業")
        let nextRoom = context.state.nextCourseRoom ?? "-"

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nextName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text("次は")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.iosOrange.opacity(0.2))
                        .foregroundStyle(Color.iosOrange)
                        .clipShape(.rect(cornerRadius: 4))

                    Text(nextRoom)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.iosOrange)
                    .multilineTextAlignment(.trailing)
                Text("開始まで")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // --- Finished ---

    private var finishedContent: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.iosGreen.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.iosGreen.gradient)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("全ての授業が終了しました")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Text("今日もお疲れ様でした！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dynamic Island サブビュー

// Expanded Leading: 状態を示すアイコン
struct ClassActivityExpandedLeading: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle()
                    .fill(classAccentColor(context.state).gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: leadingIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(phaseName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 2)
        }
        .padding(.top, 14)
        .padding(.leading, 12)
    }

    private var leadingIcon: String {
        if context.state.hasRoomChange && context.state.phase != .breakTime && context.state.phase != .finished {
            return "exclamationmark.triangle.fill"
        }
        switch context.state.phase {
        case .imminent:   return "figure.walk"
        case .breakTime:  return "cup.and.heat.waves"
        case .finished:   return "checkmark"
        default:          return "book.fill"
        }
    }

    private var phaseName: String {
        if context.state.hasRoomChange && context.state.phase != .breakTime && context.state.phase != .finished {
            return String(localized: "教室変更")
        }
        switch context.state.phase {
        case .upcoming:   return String(localized: "準備中")
        case .imminent:   return String(localized: "まもなく")
        case .inProgress: return String(localized: "授業中")
        case .breakTime:  return String(localized: "休憩中")
        case .finished:   return String(localized: "本日終了")
        }
    }
}

// Expanded Trailing: 時限ラベル（finished は非表示）
struct ClassActivityExpandedTrailing: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>

    var body: some View {
        if context.state.phase != .finished {
            Text(periodLabel)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(classAccentColor(context.state))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(classAccentColor(context.state).opacity(0.15))
                .clipShape(Capsule())
                .padding(.top, 14)
                .padding(.trailing, 12)
        }
    }

    private var periodLabel: String {
        let period = context.state.phase == .breakTime
            ? (context.state.nextCoursePeriod ?? 0)
            : context.state.period
        return String(localized: "\(period)限")
    }
}

// Expanded Bottom: カウントダウン + 詳細情報
struct ClassActivityExpandedBottom: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if context.state.phase == .finished {
                finishedMessage
            } else {
                // Row 1: タイマー + 教室・教師チップ
                HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(timerLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                        CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(classAccentColor(context.state))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        infoChip(icon: "mappin.and.ellipse", text: roomNumber, highlight: context.state.hasRoomChange)
                        infoChip(icon: "person.fill", text: teacherName, highlight: false)
                    }
                }

                // Row 2: inProgress → 進捗バー / imminent + roomChange → アクション
                if context.state.phase == .inProgress {
                    progressSection
                } else if context.state.hasRoomChange || context.state.phase == .imminent {
                    actionMessage
                }
            }
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }

    private var progressSection: some View {
        VStack(spacing: 3) {
            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: false
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Color.iosBlue)

            HStack {
                Text(context.state.startDate, format: .dateTime.hour().minute())
                    .padding(.leading, 2)
                Spacer()
                Text(context.state.endDate, format: .dateTime.hour().minute())
                    .padding(.trailing, 2)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func infoChip(icon: String, text: String, highlight: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 12, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(highlight ? Color.iosRed : .white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(highlight ? Color.iosRed.opacity(0.2) : Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private var actionMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: context.state.hasRoomChange ? "exclamationmark.circle.fill" : "figure.walk.circle.fill")
                .font(.system(size: 15))
            Text(context.state.hasRoomChange ? String(localized: "教室が変更されました。移動してください") : String(localized: "まもなく開始です。教室へ向かいましょう"))
                .font(.system(size: 11, weight: .bold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(classAccentColor(context.state).opacity(0.2))
        .clipShape(.rect(cornerRadius: 7))
    }

    private var finishedMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.iosGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("全ての授業が終了しました")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text("今日もお疲れ様でした！")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var timerLabel: String {
        switch context.state.phase {
        case .inProgress: return String(localized: "終了まで")
        case .breakTime:  return String(localized: "次まで")
        default:          return String(localized: "開始まで")
        }
    }

    private var roomNumber: String {
        if context.state.hasRoomChange, let newRoom = context.state.newRoom {
            return newRoom
        }
        return context.state.phase == .breakTime
            ? (context.state.nextCourseRoom ?? "-")
            : context.state.room
    }

    private var teacherName: String {
        context.state.phase == .breakTime ? (context.state.nextCourseTeacher ?? "") : context.state.teacher
    }
}

// MARK: - Widget 定義

struct ClassLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassLiveActivityAttributes.self) { context in
            ClassLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ClassActivityExpandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ClassActivityExpandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(courseName(for: context))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.top, 18)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ClassActivityExpandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalContent(context: context)
            }
            .keylineTint(classAccentColor(context.state).opacity(0.45))
            .contentMargins(.horizontal, 7, for: .minimal)
            .contentMargins(.vertical, 3, for: .minimal)
        }
    }

    private func courseName(for context: ActivityViewContext<ClassLiveActivityAttributes>) -> String {
        switch context.state.phase {
        case .finished:  return String(localized: "本日終了")
        case .breakTime: return context.state.nextCourseName ?? context.state.courseName
        default:         return context.state.courseName
        }
    }

    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<ClassLiveActivityAttributes>) -> some View {
        if context.state.hasRoomChange && context.state.phase != .breakTime && context.state.phase != .finished {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.iosRed)
        } else {
            switch context.state.phase {
            case .breakTime:
                Image(systemName: "cup.and.heat.waves")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.iosOrange)
            case .finished:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.iosGreen)
            default:
                Text(String(localized: "\(context.state.period)限"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.iosBlue)
            }
        }
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<ClassLiveActivityAttributes>) -> some View {
        switch context.state.phase {
        case .imminent:
            VStack(alignment: .center, spacing: -1) {
                Text("教室").font(.system(size: 9, weight: .medium))
                    .foregroundStyle(classAccentColor(context.state))
                Text(context.state.hasRoomChange ? (context.state.newRoom ?? context.state.room) : context.state.room)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(classAccentColor(context.state))
            }
        case .finished:
            Text("終了")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.iosGreen)
        default:
            let remaining = abs(context.state.countdownDate.timeIntervalSinceNow)
            let maxW: CGFloat = remaining >= 3600 ? 54 : remaining >= 600 ? 40 : 32
            CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(classAccentColor(context.state))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: maxW, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func minimalContent(context: ActivityViewContext<ClassLiveActivityAttributes>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                minimalProgressRing(context: context, size: 20, lineWidth: 2)
                if context.state.phase == .finished {
                    Text("終了")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                } else {
                    CountdownTimerText(targetDate: context.state.countdownDate, isStale: context.isStale)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                }
            }
            .foregroundStyle(classAccentColor(context.state))

            minimalProgressRing(context: context, size: 20, lineWidth: 2)
        }
    }

    private func minimalProgressRing(
        context: ActivityViewContext<ClassLiveActivityAttributes>,
        size: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        let accentColor = classAccentColor(context.state)
        return ZStack {
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: minimalProgressValue(context))
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            minimalSymbol(for: context)
                .foregroundStyle(accentColor)
        }
        .frame(width: size, height: size)
    }

    /// 近似進捗値（描画時点で計算、秒単位の精度は不要）
    private func minimalProgressValue(_ context: ActivityViewContext<ClassLiveActivityAttributes>) -> CGFloat {
        switch context.state.phase {
        case .finished:
            return 1.0
        case .inProgress:
            let total = context.state.endDate.timeIntervalSince(context.state.startDate)
            guard total > 0 else { return 0 }
            let elapsed = Date().timeIntervalSince(context.state.startDate)
            return CGFloat(max(0, min(1, elapsed / total)))
        case .breakTime:
            return 1.0
        default:
            return 0.0
        }
    }

    @ViewBuilder
    private func minimalSymbol(for context: ActivityViewContext<ClassLiveActivityAttributes>) -> some View {
        if context.state.hasRoomChange && context.state.phase != .breakTime && context.state.phase != .finished {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
        } else {
            switch context.state.phase {
            case .breakTime:
                Image(systemName: "cup.and.heat.waves")
                    .font(.system(size: 11, weight: .bold))
            case .finished:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
            default:
                Text("\(context.state.period)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - サンプルデータ

private extension ClassLiveActivityAttributes {
    static let preview = ClassLiveActivityAttributes()
}

private extension ClassLiveActivityAttributes.ContentState {
    static let upcoming = ClassLiveActivityAttributes.ContentState(
        phase: .upcoming,
        countdownDate: Date().addingTimeInterval(90 * 60),
        courseName: "情報工学概論",
        room: "242",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(90 * 60),
        endDate: Date().addingTimeInterval(90 * 60 + 90 * 60)
    )
    static let imminent = ClassLiveActivityAttributes.ContentState(
        phase: .imminent,
        countdownDate: Date().addingTimeInterval(3 * 60),
        courseName: "情報工学概論",
        room: "242",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(3 * 60),
        endDate: Date().addingTimeInterval(3 * 60 + 90 * 60)
    )
    static let roomChangeUpcoming = ClassLiveActivityAttributes.ContentState(
        phase: .upcoming,
        countdownDate: Date().addingTimeInterval(20 * 60),
        courseName: "情報工学概論",
        room: "101",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(20 * 60),
        endDate: Date().addingTimeInterval(20 * 60 + 90 * 60),
        hasRoomChange: true,
        newRoom: "101"
    )
    static let roomChangeInProgress = ClassLiveActivityAttributes.ContentState(
        phase: .inProgress,
        countdownDate: Date().addingTimeInterval(45 * 60),
        courseName: "情報工学概論",
        room: "101",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(-45 * 60),
        endDate: Date().addingTimeInterval(45 * 60),
        hasRoomChange: true,
        newRoom: "101"
    )
    static let inProgress = ClassLiveActivityAttributes.ContentState(
        phase: .inProgress,
        countdownDate: Date().addingTimeInterval(45 * 60),
        courseName: "情報工学概論",
        room: "242",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(-45 * 60),
        endDate: Date().addingTimeInterval(45 * 60)
    )
    static let breakTime = ClassLiveActivityAttributes.ContentState(
        phase: .breakTime,
        countdownDate: Date().addingTimeInterval(10 * 60),
        courseName: "情報工学概論",
        room: "242",
        teacher: "中村 教授",
        period: 1,
        startDate: Date().addingTimeInterval(-90 * 60),
        endDate: Date(),
        hasRoomChange: false,
        newRoom: nil,
        nextCourseName: "Webプログラミング",
        nextCourseRoom: "201",
        nextCourseTeacher: "佐藤 准教授",
        nextCoursePeriod: 2
    )
    static let finished = ClassLiveActivityAttributes.ContentState(
        phase: .finished,
        countdownDate: Date(),
        courseName: "Webプログラミング",
        room: "201",
        teacher: "佐藤 准教授",
        period: 2,
        startDate: Date().addingTimeInterval(-90 * 60),
        endDate: Date()
    )
}

// MARK: - プレビュー（ロック画面）

#Preview("全フェーズ - ロック画面", as: .content, using: ClassLiveActivityAttributes.preview) {
    ClassLiveActivityWidget()
} contentStates: {
    ClassLiveActivityAttributes.ContentState.upcoming
    ClassLiveActivityAttributes.ContentState.imminent
    ClassLiveActivityAttributes.ContentState.roomChangeUpcoming
    ClassLiveActivityAttributes.ContentState.roomChangeInProgress
    ClassLiveActivityAttributes.ContentState.inProgress
    ClassLiveActivityAttributes.ContentState.breakTime
    ClassLiveActivityAttributes.ContentState.finished
}

// MARK: - プレビュー（Dynamic Island コンパクト）

#Preview("全フェーズ - DI コンパクト", as: .dynamicIsland(.compact), using: ClassLiveActivityAttributes.preview) {
    ClassLiveActivityWidget()
} contentStates: {
    ClassLiveActivityAttributes.ContentState.upcoming
    ClassLiveActivityAttributes.ContentState.imminent
    ClassLiveActivityAttributes.ContentState.roomChangeUpcoming
    ClassLiveActivityAttributes.ContentState.inProgress
    ClassLiveActivityAttributes.ContentState.breakTime
    ClassLiveActivityAttributes.ContentState.finished
}

// MARK: - プレビュー（Dynamic Island 展開）

#Preview("全フェーズ - DI 展開", as: .dynamicIsland(.expanded), using: ClassLiveActivityAttributes.preview) {
    ClassLiveActivityWidget()
} contentStates: {
    ClassLiveActivityAttributes.ContentState.upcoming
    ClassLiveActivityAttributes.ContentState.imminent
    ClassLiveActivityAttributes.ContentState.roomChangeUpcoming
    ClassLiveActivityAttributes.ContentState.roomChangeInProgress
    ClassLiveActivityAttributes.ContentState.inProgress
    ClassLiveActivityAttributes.ContentState.breakTime
    ClassLiveActivityAttributes.ContentState.finished
}

// MARK: - プレビュー（Dynamic Island ミニマル）

#Preview("全フェーズ - DI ミニマル", as: .dynamicIsland(.minimal), using: ClassLiveActivityAttributes.preview) {
    ClassLiveActivityWidget()
} contentStates: {
    ClassLiveActivityAttributes.ContentState.upcoming
    ClassLiveActivityAttributes.ContentState.imminent
    ClassLiveActivityAttributes.ContentState.roomChangeUpcoming
    ClassLiveActivityAttributes.ContentState.inProgress
    ClassLiveActivityAttributes.ContentState.breakTime
    ClassLiveActivityAttributes.ContentState.finished
}
