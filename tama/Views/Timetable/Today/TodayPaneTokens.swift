import SwiftUI

// MARK: - 「今日」ペインの設計トークン

/// 2ペイン表示の右側（「今日」ペイン）が使う寸法・文字の目盛り。
///
/// このペインは4枚のタイル（授業・このあとの授業・バス・課題）を弁当箱のように並べる。
/// どのタイルも同じ余白・同じ文字の段で組まれているからこそ、
/// 「位置と見出しの記号だけで種類が分かる」状態になる。数値をビューに直接書かない。
///
/// 文字は左ペインの時間割と同じく固定の `.system(size:)` で指定する
enum TodayPaneTokens {

    // MARK: - 余白

    /// 4ptを基本にした1本だけの余白の目盛り。ペインの中のすべての余白・間隔はこの6段から選ぶ
    enum Spacing {

        /// 4pt（数字と単位の間など、いちばん細かい間）
        static let xxs: CGFloat = 4

        /// 6pt（見出しの記号と文字の間）
        static let header: CGFloat = 6

        /// 8pt（見出しの行と科目名の間・ボタンとボタンの間）
        static let xs: CGFloat = 8

        /// 12pt（科目名と下の段の間・下の段と進み具合のバーの間）
        static let s: CGFloat = 12

        /// 16pt（タイルの内側の余白・組と組の間・ペインの左右の余白）
        static let m: CGFloat = 16

        /// 24pt（①の事実どうしの間）
        static let xl: CGFloat = 24
    }

    // MARK: - 文字

    /// 1本だけの文字の目盛り。用途の名前で呼び、サイズの数字はここだけに書く。
    /// ペイン全体でこの6段しか使わない
    enum Typography {

        /// 11pt（事実の名札・時刻の目盛り・小さな札）
        static let micro: CGFloat = 11

        /// 13pt（タイルの見出し・補足・ボタンの文字・足もとの入り口）
        static let caption: CGFloat = 13

        /// 15pt（一覧の行の題名・時刻・教員名・大きな数字の単位）
        static let body: CGFloat = 15

        /// 17pt（静かなタイルの一言）
        static let title: CGFloat = 17

        /// 22pt（科目名・教室）
        static let headline: CGFloat = 22

        /// 28pt（タイルにひとつだけ置く大きな数字）
        static let key: CGFloat = 28
    }

    // MARK: - 寸法

    /// 列の幅・線の太さなど、余白の目盛りから作る寸法
    enum Metrics {

        /// ペインの左右の余白（見出しの末尾側の余白もこれに合わせる）
        static let horizontalInset = Spacing.m

        /// タイルの内側の余白（上下左右とも同じ値）
        static let tilePadding = Spacing.m

        /// タイルの角丸。左ペインの時限セル（`TimeSlotCell`）と同じ値にする
        static let cornerRadius = TimeSlotCell.cornerRadius

        /// 区切り線の太さ（左ペインの時限セルの枠と同じ）
        static let hairline = CardSurface.outlineWidth

        /// 押せる高さの下限（HIG）
        static let minimumHit: CGFloat = 44

        /// 行の時刻の列の幅（②と③で同じ。17ptの太い時刻も入る幅）
        static let timeColumn: CGFloat = 54

        /// 見出しの行の高さと、見出しと中身のあいだ（`TodayStackLayout` の計算と揃える）
        static let headerHeight: CGFloat = 17
        static let headerGap = Spacing.xs

        /// 進み具合のバーの高さ
        static let progressBar = Spacing.xxs

        /// 丸いボタンの見た目の高さ（押せる高さは `minimumHit` で別に取る）
        static let buttonHeight: CGFloat = 34

        /// 丸いボタンの左右の余白
        static let buttonPadding: CGFloat = 14

        /// 丸いボタンの押せる範囲が見た目の高さからはみ出す分（高さは食わない）
        static let buttonHitOverflow: CGFloat = 5

        /// 未読件数の小さな丸札の一辺
        static let badge: CGFloat = 18

        /// 見出しの記号の大きさ（文字の目盛りではなく記号の寸法なのでここに置く）
        static let headerSymbol: CGFloat = 12

        /// 行を押したときの角丸
        static let rowCornerRadius = Spacing.xs
    }

    // MARK: - 濃さ

    /// 押している間の濃さ
    enum Opacity {

        /// 押している間
        static let pressed: Double = 0.6

        /// 行を押している間の地
        static let rowPressed: Double = 0.06
    }

    // MARK: - 色

    /// タイルごとの差し色。見出しの記号と、そのタイルの要の数字にだけ使う。
    /// 色だけに意味を持たせないため、使う側では必ず言葉を添えること
    enum Accent {

        /// 授業（上の2枚）
        static var lesson: Color { .appPrimary }

        /// 課題
        static var assignment: Color { .orange }

        /// 締切が迫っている課題
        static var urgent: Color { .red }
    }
}

// MARK: - 左の時間割の目盛り

/// 左ペインの時間割の縦の目盛り（右ペインの見出しとタイルの上端・間隔が従う）。
///
/// 右ペインは自分で上端を決めず、左ペインが `LayoutMetrics` で解いた値をそのまま受け取る。
/// これにより見出しは左のタイトル＋曜日行の帯に、最初のタイルの上端は1行目のセルの上端に重なり、
/// タイルどうしの間隔も左のセルどうしの間隔と同じになる
struct TimetableGridMetrics: Equatable {

    /// ペインの上端から1行目のセルの上端までの距離
    let gridTop: CGFloat

    /// ペインの上端から曜日の行の上端までの距離
    let weekdayRowTop: CGFloat

    /// 曜日の行の高さ
    let weekdayRowHeight: CGFloat

    /// 曜日の文字の大きさ（右ペインの日付もこれに合わせる）
    let weekdayFontSize: CGFloat

    /// セルとセルの間隔（右ペインのタイルどうしの間隔にそのまま使う）
    let rowGap: CGFloat

    /// 表そのものの高さ（1行目のセルの上端から最終行のセルの下端まで）。
    /// 右ペインのタイルの束はぴったりこの高さに収まる（めくらない）
    let gridHeight: CGFloat

    /// まだ左ペインの大きさが決まっていない状態
    static let unavailable = TimetableGridMetrics(
        gridTop: 0, weekdayRowTop: 0, weekdayRowHeight: 0, weekdayFontSize: 0,
        rowGap: 0, gridHeight: 0)

    /// 右ペインを組めるだけの値が揃っているか
    var isAvailable: Bool { gridTop > 0 && weekdayFontSize > 0 && gridHeight > 0 }
}
