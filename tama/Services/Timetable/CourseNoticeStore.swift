import Foundation

// MARK: - 授業のお知らせの控え

/// 「今日」ペインが出す、授業ごとのお知らせ（掲示）を短い間だけ覚えておくストア。
///
/// 掲示は科目詳細のAPI（`CourseDetailService.fetchCourseDetail`）にしか無いので、
/// ①の授業のタイルが出ているあいだに授業1つにつき1回だけ取りに行き、ここに控える。
/// `TimelineView` が1分ごとに描き直しても取り直さない（取得中・取得済みなら何もしない）。
///
/// 題名だけでなく掲示番号と登録日も控えるのは、①の「掲示」ボタンを押したときに
/// 科目詳細とまったく同じURLで掲示そのものを開くため。
/// 掲示された日時も控えるのは、古い掲示をこのペインに出さないため。
///
/// 取れなかったときは何も持たない。ペイン側は未読件数（`CourseModel.keijiMidokCnt`）の
/// 表示に切り替えること
@MainActor
final class CourseNoticeStore: ObservableObject {

    // MARK: - 公開プロパティ

    static let shared = CourseNoticeStore()

    /// 授業コード → お知らせ（新しい順）
    @Published private(set) var notices: [String: [TodayNotice]] = [:]

    // MARK: - プライベートプロパティ

    /// 控えを作り直すまでの時間
    private static let timeToLive: TimeInterval = 30 * 60

    /// 1つの授業について控える件数の上限
    private static let limit = 5

    private var fetchedAt: [String: Date] = [:]
    private var inFlight: Set<String> = []
    /// `clear()` のたびに進める世代番号。ログアウト前に始まった取得の結果を捨てるために使う
    private var generation = 0

    private init() {}

    // MARK: - 読み出し

    /// その授業のお知らせ（まだ無ければ nil）
    func notices(for course: CourseModel) -> [TodayNotice]? {
        guard let code = course.jugyoCd, let stored = notices[code], !stored.isEmpty else {
            return nil
        }
        return stored
    }

    // MARK: - 取得

    /// まだ控えが無い（または古い）ときだけ取りに行く
    func loadIfNeeded(for course: CourseModel) {
        guard let code = course.jugyoCd, !code.isEmpty else { return }
        guard !inFlight.contains(code) else { return }
        if let fetched = fetchedAt[code], Date().timeIntervalSince(fetched) < Self.timeToLive {
            return
        }

        #if DEBUG
        if DuoDebugTimetable.usesMockCourseDetail {
            fetchedAt[code] = Date()
            notices[code] = Self.converted(
                CourseDetailResponse.previewMock(for: course).announcements)
            return
        }
        #endif

        inFlight.insert(code)
        let requestGeneration = generation
        CourseDetailService.shared.fetchCourseDetail(course: course) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                // ログアウト（clear）後に届いた前のユーザーの結果は捨てる
                guard requestGeneration == self.generation else { return }
                self.inFlight.remove(code)
                self.fetchedAt[code] = Date()
                switch result {
                case .success(let detail):
                    self.notices[code] = Self.converted(detail.announcements)
                case .failure(let error):
                    // T-NEXTへ繋がらないときは何も持たない（未読件数の表示に任せる）
                    self.notices[code] = []
                    print("CourseNoticeStore: お知らせの取得に失敗しました - \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 破棄

    /// ログアウト時に控えを捨てる
    func clear() {
        generation += 1
        notices = [:]
        fetchedAt = [:]
        inFlight = []
    }

    /// APIの掲示をペインが使う形に直す（上限まで）
    private static func converted(_ announcements: [AnnouncementModel]) -> [TodayNotice] {
        announcements.prefix(limit).map {
            TodayNotice(
                id: $0.id, title: $0.title, torkDate: $0.torkDate,
                postedAt: Date(timeIntervalSince1970: TimeInterval($0.date / 1_000)))
        }
    }
}
