import SwiftUI

// MARK: - ④課題のタイル

/// 締切の近い課題を近い順に並べるタイル。
///
/// 数（今日・明日・全部）は見出しの行に寄せてあるので、中身は行だけになる。
/// 行の文法は②③と同じだが、課題に時刻の列は要らない（締切は文字で言えば足りる）ので
/// 題名と締切の2段だけを置く。見出しの行が課題タブへの入り口、行はそれぞれその課題への入り口
struct TodayAssignmentTile: View {

    let model: TodayAssignmentTileModel

    /// 出す行数と1行の高さ（`TodayStackLayout` が決める）
    var rows = 1
    var rowHeight = TodayStackLayout.rowHeight

    /// 縦積みのとき。④は残りの高さをそのまま受け取るので、行がそれを等分して下に帯を残さない
    var sharesFreeHeight = false

    /// 課題を押したとき（T-NEXTのURL）
    let onOpenAssignment: (String) -> Void

    /// 見出しを押したとき（課題タブへ）
    let onOpenAssignments: () -> Void

    private typealias Token = TodayPaneTokens

    /// 記号つきの「何も無い」を出してよい高さ
    private static let symbolMinimumHeight: CGFloat = 120

    /// 見出しの行を押せる高さ（タイルの上端から、1行目が始まる位置まで）
    private static let headerHitHeight = Token.Metrics.tilePadding
        + Token.Metrics.headerHeight + Token.Metrics.headerGap

    var body: some View {
        TodayTile(
            symbol: "checklist",
            title: NSLocalizedString("課題", comment: "「今日」ペインのタイルの見出し"),
            accent: accent,
            trailing: trailing,
            showsChevron: true,
            fillsHeight: true
        ) {
            content
        }
        // 見出しの行を課題タブへの入り口にする。
        // 押せる範囲は1行目の上端で止める（44ptまで伸ばすと1行目の上側を覆ってしまう）
        .overlay(alignment: .topLeading) {
            Button(action: onOpenAssignments) {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(TodayPressableStyle())
            .frame(height: Self.headerHitHeight)
            .accessibilityLabel(
                NSLocalizedString("課題", comment: "「今日」ペインのタイルの見出し"))
            .accessibilityAddTraits(.isButton)
        }
    }

    /// 差し色。締切が迫っている1件があるときだけ赤に変わる
    private var accent: Color {
        guard model.isLoaded, model.todayCount > 0 else { return .secondary }
        return model.isUrgent ? Token.Accent.urgent : Token.Accent.assignment
    }

    /// 見出しの右端。「今日 2 · 明日 2」と総数
    private var trailing: TodayTileTrailing? {
        let count = model.isLoaded && model.totalPending > 0
            ? String(
                format: NSLocalizedString("%d件", comment: "「今日」ペインの課題の件数"),
                model.totalPending)
            : nil
        guard model.isLoaded else { return count.map { TodayTileTrailing($0) } }

        return TodayTileTrailing(
            accent: String(
                localized: "今日 \(model.todayCount)",
                comment: "「今日」ペインの課題のタイルの見出しの右端。今日が締切の件数"),
            accentColor: model.todayCount > 0 ? accent : .secondary,
            plain: String(
                localized: "· 明日 \(model.tomorrowCount)",
                comment: "「今日」ペインの課題のタイルの見出しの右端。「今日 N」に続く、明日が締切の件数"),
            count: count)
    }

    // MARK: - 中身

    @ViewBuilder private var content: some View {
        if model.items.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.items.prefix(max(1, rows)).enumerated()), id: \.element.id) {
                    index, item in
                    if index > 0 { TodayHairline() }
                    row(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 出すものが本当に何も無いときだけの顔（高さに余裕があるときだけ記号を添える）
    private var empty: some View {
        GeometryReader { proxy in
            VStack(spacing: Token.Spacing.xSmall) {
                if proxy.size.height >= Self.symbolMinimumHeight {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: Token.Typography.key))
                        .foregroundStyle(.tertiary)
                }
                Text(model.emptyText ?? "")
                    .font(.system(size: Token.Typography.caption))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func row(_ item: TodayAssignmentTileModel.Item) -> some View {
        Button {
            onOpenAssignment(item.url)
        } label: {
            TodayRow(
                title: item.title,
                titleSize: Token.Typography.caption,
                titleWeight: .semibold,
                subtitle: item.detail,
                subtitleColor: item.isAccented ? Token.Accent.urgent : .secondary,
                height: rowHeight,
                sharesFreeHeight: sharesFreeHeight)
        }
        .buttonStyle(TodayRowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
