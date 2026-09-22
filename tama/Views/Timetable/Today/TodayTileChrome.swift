import SwiftUI

// MARK: - タイルの体裁

/// 「今日」ペインの4枚のタイルが共通で着る服。
///
/// 地・枠・角丸・内側の余白・見出しの組み方をここ1つに決めてしまうことで、
/// 4枚が「同じ箱の4つの仕切り」に見えるようにする。
/// 差し色は見出しの記号（と、そのタイルの要の数字）にだけ入る。
/// 記号は種類の目印であって飾りではないので、行の中には置かない。
///
/// 「もっと見る」の入り口は見出しの行の末尾の `›` で示す。
/// 下端に浮いた入り口を置かないので、中身は上端と下端の両方に接して組める
struct TodayTile<Content: View>: View {

    /// 見出しの記号（SF Symbols）
    let symbol: String

    /// 見出しの文字（「授業中 · 2限」「帰りのバス · 聖蹟桜ヶ丘駅行」など）
    let title: String

    /// そのタイルの差し色（記号に使う）
    var accent: Color = .secondary

    /// 見出しの右端に添える小さな文字（「あと2コマ」「今日 2 · 明日 2」「9件」など）
    var trailing: TodayTileTrailing?

    /// 見出しの右端に `›` を出すか（このタイルが別の画面への入り口であることの合図）
    var showsChevron = false

    /// 高さを親いっぱいに広げるか（下の段の2枚だけ true。①②は中身の高さのまま）
    var fillsHeight = false

    @ViewBuilder let content: () -> Content

    private typealias Token = TodayPaneTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content()
                .padding(.top, Token.Metrics.headerGap)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: fillsHeight ? .infinity : nil,
                    alignment: .topLeading)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsHeight ? .infinity : nil,
            alignment: .topLeading)
        .cardSurface(
            fill: CardSurface.pageFill, padding: Token.Metrics.tilePadding,
            outlined: true, cornerRadius: Token.Metrics.cornerRadius)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Spacing.header) {
            Image(systemName: symbol)
                .font(.system(size: Token.Metrics.headerSymbol, weight: .semibold))
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: Token.Typography.caption, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: Token.Spacing.xxs)

            if let trailing {
                // 幅が足りないときは、いちばん後ろの総数から先に落とす
                ViewThatFits(in: .horizontal) {
                    trailingLabel(trailing, showsCount: true)
                    trailingLabel(trailing, showsCount: false)
                }
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: Token.Typography.micro, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: Token.Metrics.headerHeight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func trailingLabel(
        _ trailing: TodayTileTrailing, showsCount: Bool
    ) -> some View {
        HStack(spacing: Token.Spacing.xxs) {
            if let accent = trailing.accent {
                Text(accent).foregroundStyle(trailing.accentColor)
            }
            if let plain = trailing.plain {
                Text(plain).foregroundStyle(.secondary)
            }
            if showsCount, let count = trailing.count {
                Text(count)
                    .foregroundStyle(.secondary)
                    .padding(.leading, trailing.plain == nil ? 0 : Token.Spacing.header)
            }
        }
        .font(.system(size: Token.Typography.caption, weight: .semibold))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - 見出しの右端

/// 見出しの右端に置く小さな文字。
/// 差し色を付けたい部分（「今日 2」）だけ分けて持ち、幅が足りないときは総数から落とす
struct TodayTileTrailing: Equatable {

    var accent: String?
    var accentColor: Color = .secondary
    var plain: String?
    var count: String?

    init(_ plain: String) {
        self.plain = plain
    }

    init(accent: String?, accentColor: Color, plain: String?, count: String?) {
        self.accent = accent
        self.accentColor = accentColor
        self.plain = plain
        self.count = count
    }
}

// MARK: - 区切り線

/// 行と行のあいだの細い線
struct TodayHairline: View {

    var leading: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(CardSurface.outlineStroke)
            .frame(height: TodayPaneTokens.Metrics.hairline)
            .padding(.leading, leading)
    }
}

// MARK: - 丸いボタン

/// タイルの中で使う小さな丸いボタン（「詳細」「掲示」）。
/// 見た目の高さは34ptだが、押せる高さはHIGの44ptを上下にはみ出させて確保する
struct TodayCapsuleButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TodayPaneTokens.Typography.caption, weight: .semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, TodayPaneTokens.Metrics.buttonPadding)
            .frame(height: TodayPaneTokens.Metrics.buttonHeight)
            .background { Capsule().fill(Color(UIColor.tertiarySystemFill)) }
            .padding(.vertical, TodayPaneTokens.Metrics.buttonHitOverflow)
            .contentShape(Rectangle())
            .padding(.vertical, -TodayPaneTokens.Metrics.buttonHitOverflow)
            .opacity(configuration.isPressed ? TodayPaneTokens.Opacity.pressed : 1)
    }
}

// MARK: - 押せるタイル

/// タイル全体を押せるようにするときの押し込み（色は変えず、薄くするだけ）
struct TodayPressableStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? TodayPaneTokens.Opacity.pressed : 1)
    }
}

// MARK: - 行の押し込み

/// 一覧の行を押している間だけ、うっすら地を敷く
struct TodayRowButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: TodayPaneTokens.Metrics.rowCornerRadius)
                    .fill(
                        configuration.isPressed
                            ? Color.primary.opacity(TodayPaneTokens.Opacity.rowPressed)
                            : Color.clear)
            }
    }
}

// MARK: - 共通の行

/// ②③④が共通で使う1行。
///
/// 3つのタイルで文法を揃えるための唯一の形:
/// `[ 時刻の列 54pt ][ 2段の文字（伸びる） ][ 右端の値（任意） ]`。
/// 行の高さは48ptで固定し、余った高さを吸わせるのは最大6ptまで。
/// 丸札・行ごとの矢印・大きな数字はここには置かない
struct TodayRow: View {

    /// 時刻の列（無ければ列ごと置かない＝課題のタイル）
    var time: String?

    /// 時刻の下の小さな文字（「3限」）
    var timeCaption: String?

    /// 時刻の右肩に付ける小さな赤い記号（バスの備考記号 ◎ / * / M）。
    /// 時刻の下に1文字だけ置くと宙に浮いて見えるので、時刻そのものに添える
    var timeMark: String?

    /// 時刻を少しだけ強く出す（バスの1本目）
    var emphasisesTime = false

    let title: String
    var titleSize = TodayPaneTokens.Typography.body
    var titleWeight: Font.Weight = .regular

    var subtitle: String?
    var subtitleColor: Color = .secondary

    /// 右端の値（「教室 113」）
    var value: TodayRowValue?

    /// 行の高さ（`TodayStackLayout` が決める）
    var height = TodayStackLayout.rowHeight

    /// 並んだ行でタイルの残りの高さを等分する（縦積みの④）。
    /// `height` を下限にして、上限は1行ぶんまで（それ以上は伸ばさず、行を足す側で埋める）
    var sharesFreeHeight = false

    /// 残り時間を秒まで出す行（バスの1本目だけ）
    var live: (target: Date, prefix: String)?

    private typealias Token = TodayPaneTokens

    /// 時刻の列を置いた行で、文字の段が始まる位置（区切り線もここから引く）
    static var textLeading: CGFloat {
        TodayPaneTokens.Metrics.timeColumn + TodayPaneTokens.Spacing.xs
    }

    var body: some View {
        HStack(spacing: Token.Spacing.xs) {
            if let time {
                VStack(alignment: .leading, spacing: 1) {
                    (Text(time)
                        .font(
                            .system(
                                size: emphasisesTime
                                    ? Token.Typography.title : Token.Typography.body,
                                weight: emphasisesTime ? .bold : .semibold))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        + Text(timeMark ?? "")
                        .font(.system(size: Token.Typography.micro, weight: .bold))
                        .foregroundColor(.red)
                        .baselineOffset(Token.Spacing.xxs + 2))
                        .minimumScaleFactor(0.85)
                    if let timeCaption {
                        Text(timeCaption)
                            .font(.system(size: Token.Typography.micro, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .frame(width: Token.Metrics.timeColumn, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: titleSize, weight: titleWeight))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                subtitleView
            }

            Spacer(minLength: Token.Spacing.xs)

            if let value {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(value.label)
                        .font(.system(size: Token.Typography.micro, weight: .semibold))
                        .foregroundStyle(value.isChanged ? Color.orange : Color.secondary)
                    Text(value.value)
                        .font(.system(size: Token.Typography.body, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(value.isChanged ? Color.orange : Color.primary)
                }
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(
            minHeight: height,
            maxHeight: sharesFreeHeight ? height + TodayStackLayout.rowHeight : height)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var subtitleView: some View {
        if let live {
            HStack(spacing: Token.Spacing.xxs) {
                Text(live.prefix)
                Text(
                    timerInterval: Date()...max(live.target, Date().addingTimeInterval(1)),
                    pauseTime: nil,
                    countsDown: true)
                    .monospacedDigit()
                    .fixedSize()
            }
            .font(.system(size: Token.Typography.caption))
            .foregroundStyle(subtitleColor)
            .lineLimit(1)
        } else if let subtitle {
            Text(subtitle)
                .font(.system(size: Token.Typography.caption))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// 行の右端に置く「名札＋値」（タイル①の事実と同じ組み方）
struct TodayRowValue: Equatable {
    let label: String
    let value: String
    var isChanged = false
}
