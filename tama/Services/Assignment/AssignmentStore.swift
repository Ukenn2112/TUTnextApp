import Foundation

// MARK: - 課題一覧の控え

/// 課題タブと時間割タブの「今日」ペインが同じ課題一覧を見るためのストア。
///
/// 画面ごとに `AssignmentService.getAssignments` を叩くと同じ内容を何度も取りに行ってしまうので、
/// 取得結果をここに1つだけ控えて、両方の画面がこれを読む。
/// 控えが新しいうちは取りに行かない（`loadIfNeeded`）ので、ネットワークは10分に1回までになる。
///
/// 引っ張って更新やタブを開いたときなど、必ず取り直したい場面では `reload()` を使う。
@MainActor
final class AssignmentStore: ObservableObject {

    // MARK: - 公開プロパティ

    static let shared = AssignmentStore()

    /// 締切が近い順
    @Published private(set) var assignments: [Assignment] = []

    @Published private(set) var isLoading = false

    @Published private(set) var errorMessage: String?

    /// 一度でも取得に成功（または失敗）して結果が出たか
    @Published private(set) var hasLoadedOnce = false

    // MARK: - プライベートプロパティ

    /// 控えを作り直すまでの時間
    private static let timeToLive: TimeInterval = 10 * 60

    /// 自分の取得が出した `.assignmentsUpdated` を受け流す猶予
    private static let selfPostGracePeriod: TimeInterval = 3

    private var fetchedAt: Date?
    private var inFlight = false
    /// `clear()` のたびに進める世代番号。ログアウト前に始まった取得の結果を捨てるために使う
    private var generation = 0
    private var observers: [NSObjectProtocol] = []

    private init() {
        // Xcode Preview ではモックデータを初期値にして、ネットワークには出ない
        if Self.isRunningForPreviews {
            assignments = Assignment.previewAssignments.sorted { $0.dueDate < $1.dueDate }
            hasLoadedOnce = true
            return
        }
        observeAssignmentsUpdated()
    }

    // MARK: - 取得

    /// 控えが無い、または10分より古いときだけ取りに行く（取得中なら何もしない）
    func loadIfNeeded() {
        guard !inFlight else { return }
        if let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.timeToLive {
            return
        }
        reload()
    }

    /// 必ず取り直す（課題タブの引っ張って更新・タブ表示時）
    func reload() {
        guard !inFlight else { return }

        // プレビュー環境ではネットワーク取得をスキップ（`previewAssignments` をそのまま表示）
        if Self.isRunningForPreviews { return }

        #if DEBUG
        // 検証用のアカウントには課題が無いため、起動引数が指定されたときはモックデータを流し込む
        if DuoDebugAssignments.usesMock {
            apply(DuoDebugAssignments.mockAssignments)
            return
        }
        #endif

        inFlight = true
        // 一度取得した後はバックグラウンドで更新し、読み込み表示への切り替えによるちらつきを防ぐ
        isLoading = !hasLoadedOnce
        errorMessage = nil

        let requestGeneration = generation
        AssignmentService.shared.getAssignments { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                // ログアウト（clear）後に届いた前のユーザーの結果は捨てる
                guard requestGeneration == self.generation else { return }
                self.inFlight = false
                self.isLoading = false
                self.hasLoadedOnce = true
                self.fetchedAt = Date()

                switch result {
                case .success(let assignments):
                    // 締切日が近い順にソート
                    self.assignments = assignments.sorted { $0.dueDate < $1.dueDate }
                case .failure(let error):
                    // 取れなかったときは前回の控えをそのまま残す
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 破棄

    /// ログアウト時に控えを捨てる
    func clear() {
        generation += 1
        inFlight = false
        assignments = []
        isLoading = false
        errorMessage = nil
        hasLoadedOnce = false
        fetchedAt = nil
    }

    // MARK: - プライベート

    /// モックデータをそのまま控えに流し込む
    private func apply(_ mock: [Assignment]) {
        assignments = mock.sorted { $0.dueDate < $1.dueDate }
        isLoading = false
        errorMessage = nil
        hasLoadedOnce = true
        fetchedAt = Date()
    }

    /// `.assignmentsUpdated` は APNS の課題数変更通知でも飛んでくる（サーバー側の課題が増減した合図）ので、
    /// 受け取ったら控えを作り直す。
    ///
    /// ただしこの通知は `AssignmentService.getAssignments` が成功したときにも自分で出している。
    /// 自分の取得が引き金になって取り直すループを避けるため、取得中と取得直後は受け流す。
    private func observeAssignmentsUpdated() {
        let observer = NotificationCenter.default.addObserver(
            forName: .assignmentsUpdated, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard !self.inFlight else { return }
                if let fetchedAt = self.fetchedAt,
                    Date().timeIntervalSince(fetchedAt) < Self.selfPostGracePeriod {
                    return
                }
                self.reload()
            }
        }
        observers.append(observer)
    }

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
