import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

// MARK: - ActivityAttributes（アプリ側と同一定義を維持すること）

struct BusLiveActivityAttributes: ActivityAttributes {
    public typealias BusActivityState = ContentState

    public struct ContentState: Codable, Hashable {
        var departureDate: Date
        var routeName: String
        var departureTimeText: String
        var specialNote: String?
    }
}

// MARK: - カラー定義

private extension Color {
    static let iosOrange = Color(red: 1.0, green: 0.624, blue: 0.039)
}

// MARK: - カウントダウンタイマー（stale 時は "0:00" 表示）

private struct BusCountdownTimerText: View {
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

struct BusLiveActivityLockScreenView: View {
    let context: ActivityViewContext<BusLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if context.isStale {
                departedContent
            } else {
                countdownContent
            }
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

            Text("\u{2022}")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 11))
                Text(String(localized: "選択したバス"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)

            Spacer()

            if !context.isStale {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.iosOrange)
                        .frame(width: 6, height: 6)
                    Text(String(localized: "\(context.state.departureTimeText)発"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.iosOrange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.iosOrange.opacity(0.1))
                .clipShape(.capsule)
            }
        }
    }

    // MARK: - カウントダウンコンテンツ

    private var countdownContent: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.iosOrange)
                    .frame(width: 3, height: 22)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(context.state.routeName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let note = context.state.specialNote {
                        Text(note)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.red)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                BusCountdownTimerText(
                    targetDate: context.state.departureDate,
                    isStale: context.isStale
                )
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.iosOrange)
                .multilineTextAlignment(.trailing)
                Text(String(localized: "発車まで"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 発車済みコンテンツ

    private var departedContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "bus.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.iosOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "バスが発車しました"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text("\(context.state.departureTimeText) \(context.state.routeName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Widget 定義

struct BusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusLiveActivityAttributes.self) { context in
            BusLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.routeName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        if let note = context.state.specialNote {
                            Text(note)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.top, 18)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.iosOrange)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalContent(context: context)
            }
            .keylineTint(Color.iosOrange.opacity(0.45))
        }
    }

    // MARK: - Compact Trailing

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        if context.isStale {
            Text(String(localized: "発車"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.iosOrange)
        } else {
            BusCountdownTimerText(
                targetDate: context.state.departureDate,
                isStale: context.isStale
            )
            .font(.system(size: 14, weight: .medium).monospacedDigit())
            .foregroundStyle(Color.iosOrange)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 54, alignment: .trailing)
        }
    }

    // MARK: - Expanded Leading

    private func expandedLeading(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.iosOrange.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "bus.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(context.isStale ? String(localized: "発車済") : String(localized: "待機中"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 2)
        }
        .padding(.top, 14)
        .padding(.leading, 12)
    }

    // MARK: - Expanded Trailing

    private func expandedTrailing(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        Text(String(localized: "\(context.state.departureTimeText)発"))
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(Color.iosOrange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.iosOrange.opacity(0.15))
            .clipShape(Capsule())
            .padding(.top, 14)
            .padding(.trailing, 12)
    }

    // MARK: - Expanded Bottom

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        if context.isStale {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.iosOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "バスが発車しました"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(context.state.departureTimeText) \(context.state.routeName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
        } else {
            HStack(alignment: .center, spacing: 8) {
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(localized: "発車まで"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    BusCountdownTimerText(
                        targetDate: context.state.departureDate,
                        isStale: context.isStale
                    )
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.iosOrange)
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Minimal（進捗リング）

    @ViewBuilder
    private func minimalContent(context: ActivityViewContext<BusLiveActivityAttributes>) -> some View {
        if context.isStale {
            minimalProgressRing(context: context, size: 20, lineWidth: 2)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    minimalProgressRing(context: context, size: 20, lineWidth: 2)
                    BusCountdownTimerText(
                        targetDate: context.state.departureDate,
                        isStale: context.isStale
                    )
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                }
                .foregroundStyle(Color.iosOrange)

                minimalProgressRing(context: context, size: 20, lineWidth: 2)
            }
        }
    }

    private func minimalProgressRing(
        context: ActivityViewContext<BusLiveActivityAttributes>,
        size: CGFloat,
        lineWidth: CGFloat
    ) -> some View {
        let progress = minimalProgressValue(context)
        return ZStack {
            Circle()
                .stroke(Color.iosOrange.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.iosOrange,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if context.isStale {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.iosOrange)
            } else {
                Image(systemName: "bus.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.iosOrange)
            }
        }
        .frame(width: size, height: size)
    }

    private func minimalProgressValue(_ context: ActivityViewContext<BusLiveActivityAttributes>) -> CGFloat {
        if context.isStale { return 1.0 }
        let total: TimeInterval = 30 * 60
        let remaining = context.state.departureDate.timeIntervalSinceNow
        guard remaining > 0 else { return 1.0 }
        let elapsed = total - remaining
        return CGFloat(max(0, min(1, elapsed / total)))
    }
}

// MARK: - サンプルデータ

private extension BusLiveActivityAttributes {
    static let preview = BusLiveActivityAttributes()
}

private extension BusLiveActivityAttributes.ContentState {
    static let waiting = BusLiveActivityAttributes.ContentState(
        departureDate: Date().addingTimeInterval(15 * 60),
        routeName: "聖蹟桜ヶ丘駅発",
        departureTimeText: "08:35"
    )
    static let soon = BusLiveActivityAttributes.ContentState(
        departureDate: Date().addingTimeInterval(3 * 60),
        routeName: "永山駅発",
        departureTimeText: "09:10"
    )
    static let specialBus = BusLiveActivityAttributes.ContentState(
        departureDate: Date().addingTimeInterval(10 * 60),
        routeName: "聖蹟桜ヶ丘駅発",
        departureTimeText: "10:00",
        specialNote: "M"
    )
    static let departed = BusLiveActivityAttributes.ContentState(
        departureDate: Date().addingTimeInterval(-60),
        routeName: "聖蹟桜ヶ丘駅行",
        departureTimeText: "17:30"
    )
}

// MARK: - プレビュー（ロック画面）

#Preview("バス - ロック画面", as: .content, using: BusLiveActivityAttributes.preview) {
    BusLiveActivityWidget()
} contentStates: {
    BusLiveActivityAttributes.ContentState.waiting
    BusLiveActivityAttributes.ContentState.soon
    BusLiveActivityAttributes.ContentState.specialBus
    BusLiveActivityAttributes.ContentState.departed
}

// MARK: - プレビュー（Dynamic Island コンパクト）

#Preview("バス - DI コンパクト", as: .dynamicIsland(.compact), using: BusLiveActivityAttributes.preview) {
    BusLiveActivityWidget()
} contentStates: {
    BusLiveActivityAttributes.ContentState.waiting
    BusLiveActivityAttributes.ContentState.soon
    BusLiveActivityAttributes.ContentState.departed
}

// MARK: - プレビュー（Dynamic Island 展開）

#Preview("バス - DI 展開", as: .dynamicIsland(.expanded), using: BusLiveActivityAttributes.preview) {
    BusLiveActivityWidget()
} contentStates: {
    BusLiveActivityAttributes.ContentState.waiting
    BusLiveActivityAttributes.ContentState.soon
    BusLiveActivityAttributes.ContentState.departed
}

// MARK: - プレビュー（Dynamic Island ミニマル）

#Preview("バス - DI ミニマル", as: .dynamicIsland(.minimal), using: BusLiveActivityAttributes.preview) {
    BusLiveActivityWidget()
} contentStates: {
    BusLiveActivityAttributes.ContentState.waiting
    BusLiveActivityAttributes.ContentState.soon
    BusLiveActivityAttributes.ContentState.departed
}
