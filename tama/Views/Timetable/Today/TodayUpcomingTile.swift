import SwiftUI

// MARK: - ②このあとの授業のタイル

/// これから始まる授業を時刻順に並べるタイル（①に出している授業は含まない）。
///
/// 終わった授業はここに出さない。左ペインの表がその役目を持っているので、
/// 右ペインは「まだ来ていないこと」だけを言う。
/// 行は③④とまったく同じ文法（時刻の列・2段の文字・右端の値）で組む
struct TodayUpcomingTile: View {

    let model: TodayUpcomingTileModel

    /// 出す行数（`TodayStackLayout` が決める）
    let limit: Int

    /// 1行の高さ
    var rowHeight = TodayStackLayout.rowHeight

    /// 行を押したとき（時限のキー）
    let onSelect: (String) -> Void

    private typealias Token = TodayPaneTokens

    private var shown: [TodayUpcomingTileModel.Row] {
        Array(model.rows.prefix(max(1, limit)))
    }

    /// 見出しの右。絞ったときだけ「ほか%dコマ」に変わる
    private var trailingText: String {
        let hidden = model.rows.count - shown.count
        if hidden > 0 {
            return String(
                format: NSLocalizedString("ほか%dコマ", comment: "「今日」ペイン"), hidden)
        }
        return String(
            format: NSLocalizedString("あと%dコマ", comment: "「今日」ペイン"), model.rows.count)
    }

    var body: some View {
        TodayTile(
            symbol: "calendar",
            title: NSLocalizedString("このあとの授業", comment: "「今日」ペインのタイルの見出し"),
            accent: Token.Accent.lesson,
            trailing: TodayTileTrailing(trailingText)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { TodayHairline(leading: TodayRow.textLeading) }
                    Button {
                        onSelect(row.id)
                    } label: {
                        TodayRow(
                            time: row.time,
                            timeCaption: row.periodLabel,
                            title: row.courseName,
                            subtitle: row.detail,
                            value: row.room.map {
                                TodayRowValue(
                                    label: row.isRoomChanged
                                        ? NSLocalizedString("教室・変更", comment: "「今日」ペイン")
                                        : NSLocalizedString("教室", comment: "「今日」ペイン"),
                                    value: $0,
                                    isChanged: row.isRoomChanged)
                            },
                            height: rowHeight)
                    }
                    .buttonStyle(TodayRowButtonStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}
