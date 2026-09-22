import CoreGraphics

// MARK: - タイルの並べ方と高さの割り付け

/// 「今日」ペインのタイルに、左の表とまったく同じ高さを配り切るための計算（表示を持たない）。
///
/// ②③④はどれも同じ48ptの行でできているので、決めるのは**行の高さではなく行の数**だけ。
/// 行を引き伸ばして高さを埋めることはしない（間延びして見えるため）。
///
/// 並べ方は2通り。読む順番（授業 → このあと → バス → 課題）はどちらでも同じなので、
/// 場所の覚えやすさは変わらない:
///
/// ```
/// 横並び                        縦積み
/// [ ①授業                ]     [ ①授業                ]
/// [ ②このあとの授業       ]     [ ②このあとの授業       ]
/// [ ③バス ][ ④課題       ]     [ ③バス（3行まで）      ]
///                               [ ④課題（残り全部）     ]
/// ```
///
/// 横並びは、③と④の両方が配られた高さぶんの行を持っているときだけ使う。
/// 片方の中身が1行以上足りないなら縦積みにして、バスは持っている行だけの高さにし、
/// 余りは課題の行が受け取る
enum TodayStackLayout {

    // MARK: - 並べ方

    enum Arrangement: Equatable {
        case sideBySide
        case stacked

        var isSideBySide: Bool { self == .sideBySide }
    }

    // MARK: - 目盛り

    /// 行の高さ（②③④で共通。2段の文字がちょうど収まる高さ）
    static let rowHeight: CGFloat = 48

    /// 端数を吸わせるために行を伸ばしてよい上限
    static let rowStretch: CGFloat = 6

    /// タイルの外枠（上下の内側余白＋見出しの行＋見出しと行のあいだ）
    static let chrome = TodayPaneTokens.Metrics.tilePadding * 2
        + TodayPaneTokens.Metrics.headerHeight + TodayPaneTokens.Metrics.headerGap

    /// 縦積みのときにバスのタイルが持てる行数の上限
    static let stackedBusRowLimit = 3

    /// ①の科目名と事実の段のあいだに足してよい上限
    static let lessonSpacingLimit: CGFloat = 12

    private static let hairline = TodayPaneTokens.Metrics.hairline

    // MARK: - 結果

    struct Result: Equatable {

        var arrangement: Arrangement = .sideBySide

        /// 「このあとの授業」に与える高さ（出さないときは nil）と行数
        var upcomingHeight: CGFloat?
        var upcomingRows = 0

        var busRows = 0
        var assignmentRows = 0

        /// すべての行に均等に足す高さ（0〜6pt）
        var rowExtra: CGFloat = 0

        /// ①の中に足す高さ（0〜12pt）
        var lessonExtra: CGFloat = 0

        var rowHeight: CGFloat { TodayStackLayout.rowHeight + rowExtra }
    }

    // MARK: - 入口

    /// - Parameters:
    ///   - total: 左の表と同じ、タイルの束に使える高さ
    ///   - gap: タイルどうしの間隔（左の表のセルの間隔）
    ///   - lessonHeight: ①の実測の高さ（まだ測れていなければ目安）
    ///   - upcomingCount: ②に出せる授業の数（0なら②を出さない）
    ///   - busCount: ③に出せる便の数
    ///   - assignmentCount: ④に出せる課題の数
    static func solve(
        total: CGFloat,
        gap: CGFloat,
        lessonHeight: CGFloat,
        upcomingCount: Int,
        busCount: Int,
        assignmentCount: Int
    ) -> Result {
        var result = Result()

        // ②は持っている行をすべて出す（入らないときだけ減らす）
        var upcoming = upcomingCount
        var bottom = CGFloat(0)
        var available = max(0, total - lessonHeight - gap)

        if upcoming > 0 {
            available = max(0, available - gap)
            while upcoming > 1, available - height(rows: upcoming) < height(rows: 1) {
                upcoming -= 1
            }
            bottom = max(0, available - height(rows: upcoming))
        } else {
            bottom = available
        }

        result.upcomingRows = upcoming
        result.upcomingHeight = upcoming > 0 ? height(rows: upcoming) : nil

        let fitting = rows(in: bottom)
        let busRows = min(max(1, busCount), fitting)
        let assignmentRows = min(max(1, assignmentCount), fitting)

        // 横並びは、両方が配られた高さをほぼ埋められるときだけ
        if fitting >= 1, fitting - busRows <= 1, fitting - assignmentRows <= 1 {
            result.busRows = busRows
            result.assignmentRows = assignmentRows
            spread(
                &result, total: total, gap: gap, lessonHeight: lessonHeight,
                bottomRows: max(busRows, assignmentRows), upcoming: upcoming)
            return result
        }

        // 縦積み: ③は持っている行だけ、④が残りを取る
        result.arrangement = .stacked
        result.busRows = min(max(1, busCount), stackedBusRowLimit)
        let busHeight = height(rows: result.busRows)
        let assignmentHeight = max(0, bottom - busHeight - gap)
        result.assignmentRows = min(
            max(1, assignmentCount), max(1, rows(in: assignmentHeight)))

        // 端数が1行ぶん残るなら、④の行をもう1本増やして使い切る
        let fixed = lessonHeight + gap
            + (upcoming > 0 ? height(rows: upcoming) + gap : 0) + busHeight + gap
        while result.assignmentRows < assignmentCount,
              fixed + height(rows: result.assignmentRows + 1) <= total {
            result.assignmentRows += 1
        }
        // 縦積みでは行を伸ばさない。③は中身の高さのまま組まれ、この勘定とは数ptずれるので、
        // ここで行を伸ばすと④が左の表の下端からはみ出す。
        // 端数は④の側で吸う（④は残りの高さをそのまま受け取り、行がそれを等分する）
        spread(
            &result, total: total, gap: gap, lessonHeight: lessonHeight,
            bottomRows: result.busRows + result.assignmentRows, upcoming: upcoming,
            extraGap: gap, stretchesRows: false)
        return result
    }

    // MARK: - 端数の配り方

    /// 行を最大6ptまで均等に伸ばし、それでも余るぶんは①の中へ（残りは④の下に残る）
    private static func spread(
        _ result: inout Result, total: CGFloat, gap: CGFloat, lessonHeight: CGFloat,
        bottomRows: Int, upcoming: Int, extraGap: CGFloat = 0, stretchesRows: Bool = true
    ) {
        let rowCount = upcoming + bottomRows
        guard rowCount > 0 else { return }

        let used = lessonHeight + gap
            + (upcoming > 0 ? height(rows: upcoming) + gap : 0)
            + heightOfBottom(result: result, gap: extraGap)
        var left = max(0, total - used)

        let extra = stretchesRows
            ? min(rowStretch, (left / CGFloat(rowCount)).rounded(.down))
            : 0
        result.rowExtra = extra
        left -= extra * CGFloat(rowCount)

        result.lessonExtra = min(lessonSpacingLimit, left.rounded(.down))
    }

    private static func heightOfBottom(result: Result, gap: CGFloat) -> CGFloat {
        switch result.arrangement {
        case .sideBySide:
            return height(rows: max(result.busRows, result.assignmentRows))
        case .stacked:
            return height(rows: result.busRows) + gap + height(rows: result.assignmentRows)
        }
    }

    // MARK: - 数え方

    /// 行数からタイルの高さ
    static func height(rows count: Int) -> CGFloat {
        chrome + CGFloat(count) * rowHeight + CGFloat(max(0, count - 1)) * hairline
    }

    /// その高さに入る行数
    static func rows(in height: CGFloat) -> Int {
        let space = height - chrome
        guard space >= rowHeight else { return 0 }
        return Int(((space + hairline) / (rowHeight + hairline)).rounded(.down))
    }
}
