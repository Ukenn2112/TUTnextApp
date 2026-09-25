import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// 時間割データ管理サービス
final class TimetableService {
    static let shared = TimetableService()

    /// キャッシュされた時間割データ
    private var cachedTimetableData: [String: [String: CourseModel]]?

    /// 最後にデータを取得した時間
    private var lastFetchTime: Date?

    // 現在の学期情報
    @Published var currentSemester: Semester = .current

    // 部屋変更情報を格納するディクショナリ（コース名をキーとする）
    private var roomChanges: [String: RoomChange] = [:]

    /// SwiftData ModelContext
    private var modelContext: ModelContext?

    private init() {
        setupModelContext()
        loadTimetableDataFromSwiftData()
        loadRoomChanges()
    }

    /// ModelContext を初期化
    private func setupModelContext() {
        modelContext = ModelContext(SharedModelContainer.shared)
    }

    // 時間割データを取得する関数
    func fetchTimetableData(
        completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void
    ) {
        fetchTimetableData(year: 0, termNo: 0, completion: completion)
    }

    // 指定した学期の時間割データを取得する関数
    func fetchTimetableData(
        year: Int = 0, termNo: Int = 0,
        completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void
    ) {
        // キャッシュがあればまず返す
        if let cachedData = cachedTimetableData {
            print("【時間割】キャッシュデータを返します")
            completion(.success(cachedData))
        }
        
        // バックグラウンドで新しいデータを取得（最大3回リトライ）
        fetchTimetableDataFromAPI(year: year, termNo: termNo, maxRetries: 3, completion: completion)
    }
    
    // MARK: - 取得元

    /// 時間割データの取得元
    /// T-NEXT 公式 API を優先し、失敗またはデータ不完全（教室・教員名が空）の場合のみ
    /// 自社バックエンド（Redis から教室情報を補完するプロキシ）へフォールバックする
    private enum TimetableSource {
        case tnext
        case backend

        var url: URL? {
            switch self {
            case .tnext:
                return URL(
                    string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/getJugyoKeijiMenuInfo")
            case .backend:
                return URL(string: AppConstants.backendBaseURL + "/schedule/class_bulletin")
            }
        }

        /// T-NEXT はレスポンス中の文字列が URL エンコードされている（バックエンドはデコード済み）
        var isPercentEncoded: Bool { self == .tnext }

        var logName: String {
            switch self {
            case .tnext: return "T-NEXT"
            case .backend: return "バックエンド"
            }
        }
    }

    /// API リクエストに使う認証情報
    private struct RequestCredentials {
        let username: String
        let encryptedPassword: String
    }

    /// API から取得した時間割レスポンス（statusDto.success == true 時の data 部分）
    private struct CourseListPayload {
        let data: [String: Any]
        let courseList: [[String: Any]]
    }

    // MARK: - API 取得

    /// API から時間割データを取得する内部関数
    /// 取得順: T-NEXT → （失敗または教室・教員名の欠損時のみ）バックエンド
    private func fetchTimetableDataFromAPI(
        year: Int,
        termNo: Int,
        maxRetries: Int,
        completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void
    ) {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            print("【時間割】ユーザー認証情報なし")
            finishWithFailure(TimetableError.userNotAuthenticated, completion: completion)
            return
        }

        let credentials = RequestCredentials(username: user.username, encryptedPassword: encryptedPassword)

        requestCourseList(
            from: .tnext, year: year, termNo: termNo, credentials: credentials,
            retryCount: 0, maxRetries: maxRetries
        ) { tnextResult in
            switch tnextResult {
            case .success(let payload) where self.isCourseListComplete(payload.courseList):
                self.applyCourseListPayload(
                    payload, source: .tnext, credentials: credentials, completion: completion)

            case .success(let partialPayload):
                print("【時間割】T-NEXT のデータに教室または教員名の欠損あり → バックエンドで補完を試行")
                self.requestCourseList(
                    from: .backend, year: year, termNo: termNo, credentials: credentials,
                    retryCount: 0, maxRetries: maxRetries
                ) { backendResult in
                    switch backendResult {
                    case .success(let payload):
                        self.applyCourseListPayload(
                            payload, source: .backend, credentials: credentials, completion: completion)
                    case .failure(let error):
                        print("【時間割】バックエンド補完失敗（\(error.localizedDescription)）→ T-NEXT のデータをそのまま使用")
                        self.applyCourseListPayload(
                            partialPayload, source: .tnext, credentials: credentials, completion: completion)
                    }
                }

            case .failure(let tnextError):
                print("【時間割】T-NEXT 取得失敗（\(tnextError.localizedDescription)）→ バックエンドへフォールバック")
                self.requestCourseList(
                    from: .backend, year: year, termNo: termNo, credentials: credentials,
                    retryCount: 0, maxRetries: maxRetries
                ) { backendResult in
                    switch backendResult {
                    case .success(let payload):
                        self.applyCourseListPayload(
                            payload, source: .backend, credentials: credentials, completion: completion)
                    case .failure(let backendError):
                        self.finishWithFailure(backendError, completion: completion)
                    }
                }
            }
        }
    }

    /// 全コースに教室名と教員名が揃っているか
    /// T-NEXT 側で教室・教員名が空で返る障害があったため、欠損があればバックエンドで補完する
    private func isCourseListComplete(_ courseList: [[String: Any]]) -> Bool {
        courseList.allSatisfy { course in
            let room = (course["kyostName"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let teacher = (course["kyoinName"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            return !room.isEmpty && !teacher.isEmpty
        }
    }

    /// 指定した取得元に時間割をリクエストする
    /// 通信エラー（URLError 等）・データなし・HTTP 5xx のときだけ最大 maxRetries 回、2秒間隔でリトライする。
    /// API エラー（statusDto.success == false）や解析失敗は再試行しても結果が変わらないため即座に失敗を返す
    private func requestCourseList(
        from source: TimetableSource,
        year: Int,
        termNo: Int,
        credentials: RequestCredentials,
        retryCount: Int,
        maxRetries: Int,
        completion: @escaping (Result<CourseListPayload, Error>) -> Void
    ) {
        guard let url = source.url else {
            print("【時間割】無効なエンドポイント: \(source.logName)")
            completion(.failure(TimetableError.invalidEndpoint))
            return
        }

        let requestBody: [String: Any] = [
            "plainLoginPassword": "",
            "data": [
                "kaikoNendo": year,
                "gakkiNo": termNo
            ],
            "langCd": "",
            "encryptedLoginPassword": credentials.encryptedPassword,
            "loginUserId": credentials.username,
            "productCd": "ap",
            "subProductCd": "apa"
        ]

        print("【時間割】リクエスト(\(source.logName)): \(url.absoluteString)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("【時間割】リクエスト作成失敗")
            completion(.failure(TimetableError.requestCreationFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request = CookieService.shared.addCookies(to: request)

        let retryOrFail: (Error) -> Void = { error in
            if retryCount < maxRetries {
                print("【時間割】\(source.logName) リトライ \(retryCount + 1)/\(maxRetries): \(error.localizedDescription)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    self.requestCourseList(
                        from: source, year: year, termNo: termNo, credentials: credentials,
                        retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion
                    )
                }
            } else {
                print("【時間割】\(source.logName) 最大リトライ回数に達しました: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // 通信エラーはリトライ対象
                retryOrFail(error)
                return
            }

            let httpResponse = response as? HTTPURLResponse
            if let httpResponse {
                print("【時間割】\(source.logName) HTTPステータスコード: \(httpResponse.statusCode)")
                if let responseURL = httpResponse.url {
                    CookieService.shared.saveCookies(from: httpResponse, for: responseURL.absoluteString)
                }
            }

            guard let data = data else {
                retryOrFail(TimetableError.noDataReceived)
                return
            }

            switch self.parseCourseListResponse(data, source: source) {
            case .success(let payload):
                completion(.success(payload))
            case .failure(let error):
                // サーバー側の一時的な障害（5xx）のみリトライし、API エラー・解析失敗は即座に返す
                if let statusCode = httpResponse?.statusCode, (500...599).contains(statusCode) {
                    retryOrFail(error)
                } else {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    /// レスポンスをデコードし、成功時は data 部分を返す
    private func parseCourseListResponse(
        _ data: Data, source: TimetableSource
    ) -> Result<CourseListPayload, Error> {
        guard let responseString = String(data: data, encoding: .utf8) else {
            print("【時間割】デコード失敗")
            return .failure(TimetableError.decodingFailed)
        }

        // T-NEXT は文字列が URL エンコードされているためデコードする。全角スペースは両方とも半角に統一
        let normalized: String?
        if source.isPercentEncoded {
            normalized = responseString.removingPercentEncoding?
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "+", with: " ")
        } else {
            normalized = responseString.replacingOccurrences(of: "\u{3000}", with: " ")
        }
        guard let normalized, let jsonData = normalized.data(using: .utf8) else {
            print("【時間割】デコード失敗")
            return .failure(TimetableError.decodingFailed)
        }

        print("【時間割】\(source.logName) レスポンス: \(normalized)")

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                let statusDto = json["statusDto"] as? [String: Any],
                let success = statusDto["success"] as? Bool
            else {
                print("【時間割】レスポンス解析失敗")
                return .failure(TimetableError.invalidResponse)
            }

            guard success else {
                let message = (statusDto["messageList"] as? [String])?.first ?? "Unknown error"
                print("【時間割】\(source.logName) APIエラー: \(message)")
                return .failure(TimetableError.apiError(message))
            }

            guard let payloadData = json["data"] as? [String: Any],
                let courseList = payloadData["jgkmDtoList"] as? [[String: Any]]
            else {
                print("【時間割】データ解析失敗")
                return .failure(TimetableError.dataParsingFailed)
            }

            return .success(CourseListPayload(data: payloadData, courseList: courseList))
        } catch {
            print("【時間割】JSON解析エラー: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// 取得した時間割データを反映する（学期情報の更新・変換・キャッシュ・SwiftData 保存・未読件数更新）
    private func applyCourseListPayload(
        _ payload: CourseListPayload,
        source: TimetableSource,
        credentials: RequestCredentials,
        completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void
    ) {
        let data = payload.data
        print("【時間割】\(source.logName) のデータを採用（\(payload.courseList.count)コース）")
        print("【時間割】全未読掲示数: \(data["keijiCnt"] as? Int ?? 0)")

        // 授業年度と学期
        let semesterYear = data["nendo"] as? Int ?? 0
        let semesterTermNo = data["gakkiNo"] as? Int ?? 0
        let semesterName = data["gakkiName"] as? String ?? ""

        // 学期情報を更新し、UserDefaultsに永続化
        DispatchQueue.main.async {
            self.currentSemester = Semester(
                year: semesterYear,
                termNo: semesterTermNo,
                termName: semesterName
            )
            UserDefaults.standard.set(semesterYear, forKey: "semester_year")
            UserDefaults.standard.set(semesterTermNo, forKey: "semester_termNo")
            UserDefaults.standard.set(semesterName, forKey: "semester_termName")
        }

        // 時間割データの変換
        let timetableData = convertToTimetableData(payload.courseList)

        // メモリ内キャッシュの更新と SwiftData 操作はメインスレッドで実行
        // （キャッシュの読み手はメインスレッドのため、書き込みもメインに揃える）
        DispatchQueue.main.async {
            // 取得中にログアウト・別ユーザーでの再ログインがあった場合は前のユーザーのデータを捨てる
            guard UserService.shared.getCurrentUser()?.username == credentials.username else {
                print("【時間割】ユーザーが変わったため取得結果を破棄します")
                return
            }
            self.cachedTimetableData = timetableData
            self.lastFetchTime = Date()
            self.saveTimetableData(timetableData)
        }

        // 未読件数を更新してから時間割データを返す
        UserService.shared.updateAllKeijiMidokCnt(
            keijiCnt: data["keijiCnt"] as? Int ?? 0
        ) {
            print(
                "【時間割】変換後データ: \(timetableData.keys) 曜日, 合計\(timetableData.values.flatMap { $0.values }.count)コース"
            )
            completion(.success(timetableData))
        }
    }

    /// 取得失敗時の処理: 12時間以内のキャッシュがあればそれを使い続け、なければエラーを返す
    /// キャッシュはメインスレッドでのみ読み書きするため、判定もメインスレッドで行う
    private func finishWithFailure(
        _ error: Error,
        completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void
    ) {
        DispatchQueue.main.async {
            if self.cachedTimetableData == nil || !self.isCacheValid() {
                print("【時間割】有効なキャッシュがありません（12時間以上経過）: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("【時間割】取得失敗、キャッシュを使用します（有効期限内）")
            }
        }
    }

    // APIレスポンスを時間割データに変換
    private func convertToTimetableData(_ courseList: [[String: Any]]) -> [String: [String:
        CourseModel]] {
        var timetableData: [String: [String: CourseModel]] = [:]

        for courseData in courseList {
            guard let courseName = courseData["jugyoName"] as? String,
                let weekdayNumber = courseData["kaikoYobi"] as? Int,
                let periodNumber = courseData["jigenNo"] as? Int,
                let academicYear = courseData["nendo"] as? Int,
                let courseYear = courseData["kaikoNendo"] as? Int,
                let courseTerm = courseData["gakkiNo"] as? Int,
                let keijiMidokCnt = courseData["keijiMidokCnt"] as? Int
            else {
                print("【時間割】コースデータの解析に失敗: \(courseData)")
                continue
            }

            // kyostName / kyoinName は null の場合がある（欠損時はバックエンド補完を試みるが、コース自体は落とさない）
            let roomName = courseData["kyostName"] as? String ?? ""
            let teacherName = courseData["kyoinName"] as? String ?? ""

            // jugyoCd は Int または String で返る場合がある
            let jugyoCd: String
            if let cd = courseData["jugyoCd"] as? String {
                jugyoCd = cd
            } else if let cd = courseData["jugyoCd"] as? Int {
                jugyoCd = String(cd)
            } else {
                print("【時間割】コースデータの解析に失敗: \(courseData)")
                continue
            }

            // jugyoKbn は Int または String で返る場合がある
            let jugyoKbn: String
            if let kbn = courseData["jugyoKbn"] as? String {
                jugyoKbn = kbn
            } else if let kbn = courseData["jugyoKbn"] as? Int {
                jugyoKbn = String(kbn)
            } else {
                jugyoKbn = ""
            }

            // jugyoStartTime / jugyoEndTime は "HH:MM" 文字列または HHMM 整数で返る場合がある
            let startTime: String
            if let t = courseData["jugyoStartTime"] as? String {
                startTime = t
            } else if let t = courseData["jugyoStartTime"] as? Int {
                startTime = String(format: "%02d:%02d", t / 100, t % 100)
            } else {
                startTime = ""
            }
            let endTime: String
            if let t = courseData["jugyoEndTime"] as? String {
                endTime = t
            } else if let t = courseData["jugyoEndTime"] as? Int {
                endTime = String(format: "%02d:%02d", t / 100, t % 100)
            } else {
                endTime = ""
            }

            // 保存されている色インデックスを取得、なければデフォルト値を使用
            let colorIndex = CourseColorService.shared.getCourseColor(jugyoCd: jugyoCd) ?? 1

            // 部屋変更情報があれば、それを適用する
            var finalRoomName = roomName.replacingOccurrences(of: "教室", with: "")
            if let roomChange = roomChanges[courseName], Date() < roomChange.expiryDate {
                finalRoomName = roomChange.newRoom
            }

            // CourseModelを作成
            let courseModel = CourseModel(
                name: courseName,
                room: finalRoomName,
                teacher: teacherName,
                startTime: startTime,
                endTime: endTime,
                colorIndex: colorIndex,
                weekday: weekdayNumber,
                period: periodNumber,
                jugyoCd: jugyoCd,
                academicYear: academicYear,
                courseYear: courseYear,
                courseTerm: courseTerm,
                jugyoKbn: jugyoKbn,
                keijiMidokCnt: keijiMidokCnt
            )

            // 曜日の整数値を文字列に変換（1-7を使用）
            let dayKey = "\(weekdayNumber)"

            // 時限を文字列に変換
            let period = "\(periodNumber)"

            // 時間割データに追加
            if timetableData[dayKey] == nil {
                timetableData[dayKey] = [:]
            }
            timetableData[dayKey]?[period] = courseModel
        }

        return timetableData
    }

    // MARK: - SwiftData 保存・読み込み

    /// SwiftData に時間割データを保存
    private func saveTimetableData(_ timetableData: [String: [String: CourseModel]]) {
        guard let context = modelContext else { return }

        do {
            let encodedData = try JSONEncoder().encode(timetableData)
            let now = Date()

            // 既存レコードを検索
            let descriptor = FetchDescriptor<CachedTimetable>(
                predicate: #Predicate { $0.key == "timetable" }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.data = encodedData
                existing.lastFetchTime = now
            } else {
                let record = CachedTimetable(data: encodedData, lastFetchTime: now)
                context.insert(record)
            }

            try context.save()
            print("【時間割】SwiftData にデータを保存しました")

            // ウィジェットを更新
            WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
        } catch {
            print("【時間割】SwiftData への保存に失敗: \(error.localizedDescription)")
        }
    }

    /// SwiftData から時間割データを読み込む
    private func loadTimetableDataFromSwiftData() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<CachedTimetable>(
                predicate: #Predicate { $0.key == "timetable" }
            )
            if let cached = try context.fetch(descriptor).first {
                let decoded = try JSONDecoder().decode(
                    [String: [String: CourseModel]].self, from: cached.data)
                self.cachedTimetableData = decoded
                self.lastFetchTime = cached.lastFetchTime
                print("【時間割】SwiftData からデータを読み込みました（取得時間: \(formatDate(cached.lastFetchTime))）")
            }
        } catch {
            print("【時間割】SwiftData からの読み込みに失敗: \(error.localizedDescription)")
        }
    }

    /// ログアウト時にメモリ内キャッシュと共有 SwiftData の時間割を削除し、ウィジェットを更新する
    /// メインスレッドから呼ぶこと
    func clearCacheForLogout() {
        cachedTimetableData = nil
        lastFetchTime = nil

        if let context = modelContext {
            do {
                try context.delete(model: CachedTimetable.self)
                try context.save()
                print("【時間割】ログアウトに伴いキャッシュを削除しました")
            } catch {
                print("【時間割】キャッシュの削除に失敗: \(error.localizedDescription)")
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// キャッシュされた時間割データを取得
    func getCachedTimetableData() -> [String: [String: CourseModel]]? {
        return cachedTimetableData
    }
    
    /// キャッシュの有効性を確認（12時間以内かどうか）
    private func isCacheValid() -> Bool {
        guard let lastFetch = lastFetchTime else {
            return false
        }
        
        let cacheAgeHours = Date().timeIntervalSince(lastFetch) / 3600
        let isValid = cacheAgeHours < 12
        
        if !isValid {
            print("【時間割】キャッシュが期限切れです（\(String(format: "%.1f", cacheAgeHours))時間経過）")
        }
        
        return isValid
    }

    /// 日付をフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - 部屋変更関連のメソッド

    /// 部屋変更を処理する
    func handleRoomChange(courseName: String, newRoom: String) {
        print("【時間割】部屋変更処理: \(courseName) → \(newRoom)")

        // 48時間後の日時を計算
        guard let expiryDate = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) else { return }

        // 部屋変更情報を作成
        let roomChange = RoomChange(
            courseName: courseName,
            newRoom: newRoom,
            expiryDate: expiryDate
        )

        // 部屋変更情報を保存
        roomChanges[courseName] = roomChange

        // 永続化
        saveRoomChanges()

        // キャッシュされた時間割データがあれば更新
        if var timetableData = cachedTimetableData {
            updateCachedTimetableWithRoomChanges(&timetableData)

            // 更新したデータを保存
            saveTimetableData(timetableData)

            // ウィジェットを更新
            WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
        }
    }

    /// SwiftData から部屋変更情報を読み込む
    private func loadRoomChanges() {
        guard let context = modelContext else { return }

        do {
            let now = Date()
            let descriptor = FetchDescriptor<RoomChangeRecord>(
                predicate: #Predicate { $0.expiryDate > now }
            )
            let records = try context.fetch(descriptor)
            roomChanges = Dictionary(uniqueKeysWithValues: records.map {
                ($0.courseName, RoomChange(courseName: $0.courseName, newRoom: $0.newRoom, expiryDate: $0.expiryDate))
            })
            print("【時間割】部屋変更情報を読み込みました（\(roomChanges.count)件）")
        } catch {
            print("【時間割】部屋変更情報の読み込みに失敗: \(error.localizedDescription)")
            roomChanges = [:]
        }
    }

    /// 部屋変更情報を SwiftData に保存する
    private func saveRoomChanges() {
        guard let context = modelContext else { return }

        do {
            // 既存レコードを全削除
            try context.delete(model: RoomChangeRecord.self)

            // 現在の変更を保存
            for (_, change) in roomChanges {
                let record = RoomChangeRecord(
                    courseName: change.courseName,
                    newRoom: change.newRoom,
                    expiryDate: change.expiryDate
                )
                context.insert(record)
            }

            try context.save()
            print("【時間割】部屋変更情報を保存しました（\(roomChanges.count)件）")
        } catch {
            print("【時間割】部屋変更情報の保存に失敗: \(error.localizedDescription)")
        }
    }

    /// キャッシュされた時間割データを部屋変更情報で更新する
    private func updateCachedTimetableWithRoomChanges(
        _ timetableData: inout [String: [String: CourseModel]]
    ) {
        // 現在の日時
        let now = Date()

        // すべての曜日と時限をループ
        for (dayKey, dayData) in timetableData {
            for (periodKey, course) in dayData {
                // 部屋変更情報があり、期限内かチェック
                if let roomChange = roomChanges[course.name], roomChange.expiryDate > now {
                    // 部屋情報を更新した新しいCourseModelを作成
                    let updatedCourse = CourseModel(
                        name: course.name,
                        room: roomChange.newRoom,
                        teacher: course.teacher,
                        startTime: course.startTime,
                        endTime: course.endTime,
                        colorIndex: course.colorIndex,
                        weekday: course.weekday,
                        period: course.period,
                        jugyoCd: course.jugyoCd,
                        academicYear: course.academicYear,
                        courseYear: course.courseYear,
                        courseTerm: course.courseTerm,
                        jugyoKbn: course.jugyoKbn,
                        keijiMidokCnt: course.keijiMidokCnt
                    )

                    // 更新したコースで置き換え
                    timetableData[dayKey]?[periodKey] = updatedCourse
                }
            }
        }
    }

    /// 指定した授業に、いま有効な教室変更があればそれを返す。
    ///
    /// 教室そのものは `convertToTimetableData(_:)` の時点で差し替え済みなので、
    /// 呼び出し側は「変更後の教室かどうか」を示すためだけにこれを使う。
    /// 判定の条件（コース名をキーにする・期限内のみ有効）は保存側と同じものを使う
    func roomChange(forCourseNamed courseName: String) -> RoomChange? {
        guard let change = roomChanges[courseName], change.expiryDate > Date() else { return nil }
        return change
    }

    /// 期限切れの部屋変更情報をクリーンアップする
    func cleanupExpiredRoomChanges() {
        let now = Date()
        let oldCount = roomChanges.count

        // 期限切れの部屋変更を削除
        roomChanges = roomChanges.filter { $0.value.expiryDate > now }

        if oldCount != roomChanges.count {
            print("【時間割】期限切れの部屋変更情報を削除しました（\(oldCount - roomChanges.count)件）")
            saveRoomChanges()

            // キャッシュされた時間割データを更新
            if var timetableData = cachedTimetableData {
                updateCachedTimetableWithRoomChanges(&timetableData)
                saveTimetableData(timetableData)
            }
        }
    }
}
