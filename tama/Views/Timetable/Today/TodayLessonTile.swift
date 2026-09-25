import SwiftUI

// MARK: - ①授業のタイル

/// ペインの一番上に置く、いまの授業／次の授業のタイル。
///
/// ここは**いつでも授業の話しかしない**。時刻によってバスの話に入れ替わったりしないので、
/// 利用者は「一番上を見れば授業」と覚えたまま使える。
/// 科目の色は使わない（左の表のセルと同じ色で塗ると、色が意味を持っているように見えてしまう）。
/// 差し色は見出しの記号と進み具合のバーだけ。大きな数字は黒のまま置く
struct TodayLessonTile: View {

    let model: TodayLessonTileModel

    /// 科目名と事実の段のあいだに足す高さ（束の端数をここで吸う）
    var extraSpacing: CGFloat = 0

    /// 「詳細」を押したとき（時限のキー）
    let onSelect: (String) -> Void

    /// 「掲示」を押したとき（題名が取れていなければ nil が渡る）
    let onOpenNotice: (TodayNotice?, String) -> Void

    private typealias Token = TodayPaneTokens

    var body: some View {
        switch model.content {
        case .lesson(let lesson): tile(lesson)
        case .quiet(let text): quiet(text)
        }
    }

    // MARK: - 授業があるとき

    private func tile(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        TodayTile(
            symbol: "book.fill",
            title: title(lesson),
            accent: Token.Accent.lesson
        ) {
            VStack(alignment: .leading, spacing: 0) {
                headline(lesson)

                bottomRail(lesson)
                    .padding(.top, Token.Spacing.small + extraSpacing)

                if let progress = lesson.progress {
                    self.progress(lesson, value: progress)
                        .padding(.top, Token.Spacing.small)
                }
            }
        }
    }

    private func title(_ lesson: TodayLessonTileModel.Lesson) -> String {
        let period = lesson.periodNumber
        return lesson.state == .inClass
            ? String(
                localized: "授業中 · \(period)限",
                comment: "「今日」ペインの授業のタイルの見出し。授業中の時限")
            : String(
                localized: "次の授業 · \(period)限",
                comment: "「今日」ペインの授業のタイルの見出し。次の授業の時限")
    }

    /// 科目名と、その右に置く要の数字（残り時間）
    private func headline(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        HStack(alignment: .top, spacing: Token.Spacing.medium) {
            Text(lesson.courseName)
                .font(.system(size: Token.Typography.headline, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 0) {
                Text(
                    lesson.state == .inClass
                        ? NSLocalizedString("残り", comment: "「今日」ペイン")
                        : NSLocalizedString("開始まで", comment: "「今日」ペイン")
                )
                .font(.system(size: Token.Typography.micro, weight: .semibold))
                .foregroundStyle(.secondary)

                remaining(lesson)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 残り時間。10分を切ったあいだだけ、システムが秒まで描き直す m:ss に切り替える
    @ViewBuilder private func remaining(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        let live = lesson.remaining > 0 && lesson.remaining <= TodayFormat.liveThreshold
        if live {
            Text(
                timerInterval: Date()...max(lesson.systemTarget, Date().addingTimeInterval(1)),
                pauseTime: nil,
                countsDown: true
            )
            .font(.system(size: Token.Typography.key, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                ForEach(TodayFormat.durationParts(lesson.remaining)) { part in
                    Text(part.value)
                        .font(.system(size: Token.Typography.key, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(part.unit)
                        .font(.system(size: Token.Typography.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    // MARK: - 下の段

    /// タイルの底に敷く1本の段。左に名札の付いた事実（教室・教員）、右に押せるもの。
    /// 事実の値とボタンが同じ底の線に乗るので、2つの組が1本の段に見える
    private func bottomRail(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        HStack(alignment: .bottom, spacing: Token.Spacing.small) {
            facts(lesson)
            Spacer(minLength: Token.Spacing.xSmall)
            actions(lesson)
        }
    }

    /// 名札の付いた事実を横に並べる（教室・教員）。
    /// 名札の上端はそろえ、値は同じ高さの箱の底にそろえるので、どちらも1本の線に乗って見える
    private func facts(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        HStack(alignment: .top, spacing: Token.Spacing.xLarge) {
            roomFact(lesson)
            if let teacher = lesson.teacher {
                fact(label: NSLocalizedString("教員", comment: "「今日」ペイン")) {
                    Text(teacher)
                        .font(.system(size: Token.Typography.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func roomFact(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        let room = lesson.room.isEmpty ? "—" : lesson.room
        if let previous = lesson.previousRoom {
            fact(
                label: NSLocalizedString("教室 · 変更あり", comment: "「今日」ペイン"),
                labelColor: .orange
            ) {
                HStack(alignment: .lastTextBaseline, spacing: Token.Spacing.xSmall) {
                    Text(room)
                        .font(.system(size: Token.Typography.headline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.orange)
                    Text(previous)
                        .font(.system(size: Token.Typography.body))
                        .monospacedDigit()
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: NSLocalizedString("教室変更 %@ から %@", comment: "「今日」ペイン"),
                    previous, room))
        } else {
            fact(label: NSLocalizedString("教室", comment: "「今日」ペイン")) {
                Text(room)
                    .font(.system(size: Token.Typography.headline, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }

    /// 名札と値の組（名札は小さく、値は大きく）
    private func fact<Value: View>(
        label: String,
        labelColor: Color = .secondary,
        @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: Token.Typography.micro, weight: .semibold))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            value()
                .frame(height: Self.factValueBox, alignment: .bottomLeading)
        }
    }

    /// 値の行の高さ（いちばん大きい値＝教室の行の高さに合わせる）
    private static var factValueBox: CGFloat {
        UIFont.systemFont(ofSize: TodayPaneTokens.Typography.headline, weight: .bold).lineHeight
    }

    // MARK: - 進み具合

    /// 授業中だけ引く。開始時刻と終了時刻のあいだに置くので意味が一意に決まる
    private func progress(_ lesson: TodayLessonTileModel.Lesson, value: Double) -> some View {
        HStack(spacing: Token.Spacing.xSmall) {
            Text(lesson.startTime)
            Capsule()
                .fill(Color(UIColor.tertiarySystemFill))
                .frame(height: Token.Metrics.progressBar)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Token.Accent.lesson)
                            .frame(width: proxy.size.width * value)
                    }
                }
            Text(lesson.endTime)
        }
        .font(.system(size: Token.Typography.micro, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    // MARK: - ボタン

    /// 押せるものはここにだけ置く（タイルそのものは押せない）
    private func actions(_ lesson: TodayLessonTileModel.Lesson) -> some View {
        HStack(spacing: Token.Spacing.xSmall) {
            Button {
                onSelect(lesson.period)
            } label: {
                Text(NSLocalizedString("詳細", comment: "「今日」ペイン"))
            }
            .buttonStyle(TodayCapsuleButtonStyle())

            if lesson.showsNotice {
                Button {
                    onOpenNotice(lesson.notice, lesson.period)
                } label: {
                    HStack(spacing: Token.Spacing.xxSmall) {
                        Text(NSLocalizedString("掲示", comment: "「今日」ペイン"))
                        if lesson.unreadCount > 0 {
                            badge(lesson.unreadCount)
                        }
                    }
                }
                .buttonStyle(TodayCapsuleButtonStyle())
            }
        }
        .fixedSize()
    }

    private func badge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: Token.Typography.micro, weight: .bold))
            .foregroundStyle(.white)
            .monospacedDigit()
            .padding(.horizontal, Token.Spacing.xxSmall)
            .frame(minWidth: Token.Metrics.badge, minHeight: Token.Metrics.badge)
            .background { Capsule().fill(Token.Accent.lesson) }
    }

    // MARK: - 授業が無いとき

    /// 出す授業が無い日の顔。同じ体裁・同じ場所のまま、一言だけで終える
    private func quiet(_ text: String) -> some View {
        TodayTile(
            symbol: "book.fill",
            title: NSLocalizedString("授業", comment: "「今日」ペインのタイルの見出し")
        ) {
            Text(text)
                .font(.system(size: Token.Typography.title, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
