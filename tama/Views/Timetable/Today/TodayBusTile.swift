import SwiftUI

// MARK: - ③バスのタイル

/// これから乗れる便を時刻順に並べるタイル。
///
/// 便は駅で分けない。いまの向き（朝なら学校行き、放課後なら駅行き）の両方の路線を混ぜて
/// 時刻順に並べ、どれに乗るかは行き先の名前で見分けてもらう。
/// 1本目だけ時刻を少し大きくし、その行の2段目に状態（あと何分・間に合うか）を置く。
/// 行の文法は②④とまったく同じ。タイル全体がバスタブへの入り口で、押せることは見出しの `›` で示す
struct TodayBusTile: View {

    let model: TodayBusTileModel

    /// 高さを親いっぱいに広げるか（横並びのときだけ。縦積みでは中身の高さのまま）
    var fillsHeight = true

    /// 出す行数と1行の高さ（`TodayStackLayout` が決める）
    var rows = 1
    var rowHeight = TodayStackLayout.rowHeight

    let onOpenBus: (BusSchedule.RouteType) -> Void

    private typealias Token = TodayPaneTokens

    var body: some View {
        Button {
            onOpenBus(model.route)
        } label: {
            TodayTile(
                symbol: "bus.fill", title: title, accent: accent,
                showsChevron: true, fillsHeight: fillsHeight
            ) {
                content
            }
        }
        .buttonStyle(TodayPressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 見出し

    private var title: String {
        model.isTowardSchool
            ? NSLocalizedString("行きのバス", comment: "「今日」ペイン")
            : NSLocalizedString("帰りのバス", comment: "「今日」ペイン")
    }

    /// 見出しの記号の色。便が無いとき・まだ数えないときは灰色のままにする
    private var accent: Color {
        model.rows.first?.urgency?.color ?? .secondary
    }

    // MARK: - 中身

    @ViewBuilder private var content: some View {
        if model.rows.isEmpty {
            Text(model.emptyText ?? "")
                .font(.system(size: Token.Typography.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.rows.prefix(max(1, rows)).enumerated()), id: \.element.id) {
                    index, row in
                    if index > 0 { TodayHairline(leading: TodayRow.textLeading) }
                    self.row(row)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ row: TodayBusTileModel.Row) -> some View {
        let live = row.isKey && row.remaining > 0 && row.remaining <= TodayFormat.liveThreshold
        return TodayRow(
            time: row.time,
            timeMark: row.note,
            emphasisesTime: row.isKey,
            title: row.name,
            titleSize: Token.Typography.caption,
            titleWeight: .semibold,
            subtitle: live ? nil : row.status,
            subtitleColor: color(of: row.statusStyle),
            height: rowHeight,
            live: live
                ? (target: row.systemTarget, prefix: NSLocalizedString("あと", comment: "「今日」ペイン"))
                : nil)
    }

    private func color(of style: TodayBusTileModel.StatusStyle) -> Color {
        switch style {
        case .plain: return .secondary
        case .warning: return .orange
        case .urgency(let level): return level.color
        }
    }
}
