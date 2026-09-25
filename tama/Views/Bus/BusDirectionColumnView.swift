import SwiftUI

// MARK: - 1方向の列

/// バスの2列表示で、片方向（駅発または駅行）だけを受け持つ列。
///
/// 中身は1列表示とまったく同じ部品を、同じ順番で積む:
/// 見出し（路線名と向き）→ 浮かぶ時刻カード（次のバスまで／選択したバスまで）→ その方向の時刻表。
/// 左右の列は同じこのビューを路線だけ変えて使うので、行の高さも位置も必ず一致する。
///
/// 時刻カードは、いちばん背の高い場面（選択中）の高さを常に確保する（`reservesTallestHeight`）。
/// 片方が「本日の運行は終了しました」でもう片方がカウントダウン、という場面でもカードの高さが変わらず、
/// 下の時刻表が左右で同じ線から始まる。
/// そのうえで時刻表を下げる量は列ごとの実測ではなく**左右の実測のうち高いほう**（`sharedTimeCardHeight`）で、
/// 万一カードの高さがずれても2つの表の見出し行は同じ線に乗る
struct BusDirectionColumnView: View {

    // MARK: - プロパティ

    @ObservedObject var viewModel: BusScheduleViewModel

    /// この列が受け持つ路線
    let route: BusSchedule.RouteType

    /// 左右の列で共有する時刻カードの高さ（＝両列の実測のうち高いほう）。
    /// 時刻表はこの高さだけ下げるので、左右の表は必ず同じ線から始まる
    let sharedTimeCardHeight: CGFloat

    /// この列の時刻カードの実測の高さを親へ返す
    let onTimeCardHeightChange: (CGFloat) -> Void

    /// この列の時刻表の下に「備考」を出すかどうか（ページに1回だけ出すので右の列だけ true）
    let showsSpecialNotes: Bool

    // MARK: - ボディ

    var body: some View {
        VStack(alignment: .leading, spacing: BusLayout.TwoPane.columnHeaderBottomSpacing) {
            header

            ZStack(alignment: .top) {
                BusTimeTableContent(
                    viewModel: viewModel, route: route, showsSpecialNotes: showsSpecialNotes
                )
                .padding(.top, BusLayout.TwoPane.timeCardTopInset + sharedTimeCardHeight)

                BusTimeCardView(
                    viewModel: viewModel,
                    route: route,
                    showsPinMessage: false,
                    reservesTallestHeight: true
                )
                .padding(.horizontal, BusLayout.horizontalPadding)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    onTimeCardHeightChange(newHeight)
                }
                .padding(.top, BusLayout.TwoPane.timeCardTopInset)
            }
        }
    }

    // MARK: - サブビュー

    /// 列の見出し（路線名＋向きの補足）。
    /// 路線名は1列表示の路線チップとまったく同じ訳語を使う
    private var header: some View {
        HStack(spacing: BusLayout.Spacing.xs) {
            Image(systemName: route.isTowardSchool ? "graduationcap.fill" : "tram.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(route.displayName)
                .font(BusLayout.TwoPane.columnTitleFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(route.directionHint)
                .font(BusLayout.TwoPane.columnHintFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, BusLayout.horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 向きの補足

extension BusSchedule.RouteType {

    /// 列の見出しの末尾に出す、向きの短い補足
    var directionHint: String {
        isTowardSchool
            ? NSLocalizedString("駅から学校へ", comment: "バスの向き")
            : NSLocalizedString("学校から駅へ", comment: "バスの向き")
    }
}
