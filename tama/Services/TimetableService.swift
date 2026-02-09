import Foundation
import SwiftUI
import WidgetKit

/// 部屋変更の情報を保持するモデル
struct RoomChange: Codable {
    let courseName: String
    let newRoom: String
    let expiryDate: Date
}

/// 時間割データ管理サービス
final class TimetableService {
    static let shared = TimetableService()

    /// App Group ID
    private let appGroupID = "group.com.meikenn.tama"

    /// キャッシュされた時間割データ
    private var cachedTimetableData: [String: [String: CourseModel]]?

    /// 最後にデータを取得した時間
    private var lastFetchTime: Date?

    // 現在の学期情報
    @Published var currentSemester: Semester = .current

    // 部屋変更情報を格納するディクショナリ（コース名をキーとする）
    private var roomChanges: [String: RoomChange] = [:]

    private init() {
        // 起動時にApp Groupsからデータを読み込む
        loadTimetableDataFromAppGroup()
        // 部屋変更情報を読み込む
        loadRoomChanges()
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
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            print("【時間割】ユーザー認証情報なし")
            completion(.failure(TimetableError.userNotAuthenticated))
            return
        }

        // API リクエストの準備
        guard
            let url = URL(
                string:
                    "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/getJugyoKeijiMenuInfo"
            )
        else {
            print("【時間割】無効なエンドポイント")
            completion(.failure(TimetableError.invalidEndpoint))
            return
        }

        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "plainLoginPassword": "",
            "data": [
                "kaikoNendo": year,
                "gakkiNo": termNo,
            ],
            "langCd": "",
            "encryptedLoginPassword": encryptedPassword,
            "loginUserId": user.username,
            "productCd": "ap",
            "subProductCd": "apa",
        ]

        // リクエストデータをログに出力
        print("【時間割】リクエスト: \(url.absoluteString)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: requestBody),
            let jsonStr = String(data: jsonString, encoding: .utf8)
        {
            print("【時間割】リクエストボディ: \(jsonStr)")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("【時間割】リクエスト作成失敗")
            completion(.failure(TimetableError.requestCreationFailed))
            return
        }

        // リクエストの設定
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // リクエストにCookieを追加
        request = CookieService.shared.addCookies(to: request)

        // APIリクエストの実行
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("【時間割】エラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // HTTPレスポンスをログに出力
            if let httpResponse = response as? HTTPURLResponse {
                print("【時間割】HTTPステータスコード: \(httpResponse.statusCode)")

                // 保存Cookie
                if let url = response?.url {
                    CookieService.shared.saveCookies(from: response!, for: url.absoluteString)
                    print("【時間割】Cookieを保存しました")
                }
            }

            guard let data = data else {
                print("【時間割】データなし")
                completion(.failure(TimetableError.noDataReceived))
                return
            }

            // 生のレスポンスデータをログに出力
            if let rawResponseString = String(data: data, encoding: .utf8) {
                print("【時間割】生レスポンス: \(rawResponseString)")
            }

            // URLエンコードされたレスポンスをデコード
            guard let responseString = String(data: data, encoding: .utf8),
                let decodedData = responseString.removingPercentEncoding?
                    .replacingOccurrences(of: "\u{3000}", with: " ")
                    .replacingOccurrences(of: "+", with: " ")
                    .data(using: .utf8)
            else {
                print("【時間割】デコード失敗")
                completion(.failure(TimetableError.decodingFailed))
                return
            }

            // デコードされたJSONデータをログに出力
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                print("【時間割】デコード後レスポンス: \(decodedString)")
            }

            // JSONデータの解析
            do {
                if let json = try JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool
                {

                    print("【時間割】ステータス: success=\(success)")

                    if success {
                        if let data = json["data"] as? [String: Any],
                            let courseList = data["jgkmDtoList"] as? [[String: Any]]
                        {
                            print("【時間割】全未読掲示数: \(data["keijiCnt"] as? Int ?? 0)")

                            // 授業年度と学期
                            let semesterYear = data["nendo"] as? Int ?? 0
                            let semesterTermNo = data["gakkiNo"] as? Int ?? 0
                            let semesterName = data["gakkiName"] as? String ?? ""

                            // 学期情報を更新
                            DispatchQueue.main.async {
                                self.currentSemester = Semester(
                                    year: semesterYear,
                                    termNo: semesterTermNo,
                                    termName: semesterName
                                )
                            }

                            // 時間割データの変換
                            let timetableData = self.convertToTimetableData(courseList)

                            // データをApp Groupsに保存
                            self.saveTimetableDataToAppGroup(timetableData)
                            self.lastFetchTime = Date()

                            // メモリ内のキャッシュも更新
                            self.cachedTimetableData = timetableData

                            // 未読件数を更新してから時間割データを返す
                            UserService.shared.updateAllKeijiMidokCnt(
                                keijiCnt: data["keijiCnt"] as? Int ?? 0
                            ) {
                                print(
                                    "【時間割】変換後データ: \(timetableData.keys) 曜日, 合計\(timetableData.values.flatMap { $0.values }.count)コース"
                                )
                                completion(.success(timetableData))
                            }
                        } else {
                            print("【時間割】データ解析失敗")
                            completion(.failure(TimetableError.dataParsingFailed))
                        }
                    } else {
                        if let messageList = statusDto["messageList"] as? [String],
                            !messageList.isEmpty
                        {
                            let errorMessage = messageList.first ?? "Unknown error"
                            print("【時間割】APIエラー: \(errorMessage)")
                            completion(.failure(TimetableError.apiError(errorMessage)))
                        } else {
                            print("【時間割】不明なAPIエラー")
                            completion(.failure(TimetableError.apiError("Unknown error")))
                        }
                    }
                } else {
                    print("【時間割】レスポンス解析失敗")
                    completion(.failure(TimetableError.invalidResponse))
                }
            } catch {
                print("【時間割】JSON解析エラー: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // APIレスポンスを時間割データに変換
    private func convertToTimetableData(_ courseList: [[String: Any]]) -> [String: [String:
        CourseModel]]
    {
        var timetableData: [String: [String: CourseModel]] = [:]

        for courseData in courseList {
            guard let courseName = courseData["jugyoName"] as? String,
                let roomName = courseData["kyostName"] as? String,
                let teacherName = courseData["kyoinName"] as? String,
                let startTime = courseData["jugyoStartTime"] as? String,
                let endTime = courseData["jugyoEndTime"] as? String,
                let weekdayNumber = courseData["kaikoYobi"] as? Int,
                let periodNumber = courseData["jigenNo"] as? Int,
                let jugyoCd = courseData["jugyoCd"] as? String,
                let academicYear = courseData["nendo"] as? Int,
                let courseYear = courseData["kaikoNendo"] as? Int,
                let courseTerm = courseData["gakkiNo"] as? Int,
                let jugyoKbn = courseData["jugyoKbn"] as? String,
                let keijiMidokCnt = courseData["keijiMidokCnt"] as? Int
            else {
                print("【時間割】コースデータの解析に失敗: \(courseData)")
                continue
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

    /// App Groupsに時間割データを保存
    private func saveTimetableDataToAppGroup(_ timetableData: [String: [String: CourseModel]]) {
        do {
            // 時間割データをJSONデータに変換
            let encoder = JSONEncoder()
            let timetableDataEncoded = try encoder.encode(timetableData)

            // App Groupのユーザーデフォルトに保存
            DispatchQueue.main.async {
                let userDefaults = UserDefaults(suiteName: self.appGroupID)
                userDefaults?.set(timetableDataEncoded, forKey: "cachedTimetableData")
                userDefaults?.set(Date(), forKey: "lastTimetableFetchTime")

                print("【時間割】App Groupsにデータを保存しました")
                // ウィジェットを更新
                WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
            }
        } catch {
            print("【時間割】App Groupsへのデータ保存に失敗しました - \(error.localizedDescription)")
        }
    }

    /// App Groupsから時間割データを読み込む
    private func loadTimetableDataFromAppGroup() {
        DispatchQueue.main.async {
            let userDefaults = UserDefaults(suiteName: self.appGroupID)

            if let timetableData = userDefaults?.data(forKey: "cachedTimetableData"),
                let fetchTime = userDefaults?.object(forKey: "lastTimetableFetchTime") as? Date
            {
                do {
                    let decoder = JSONDecoder()
                    let timetableDataDecoded = try decoder.decode(
                        [String: [String: CourseModel]].self, from: timetableData)

                    self.cachedTimetableData = timetableDataDecoded
                    self.lastFetchTime = fetchTime

                    print("【時間割】App Groupsからデータを読み込みました（取得時間: \(self.formatDate(fetchTime))）")
                } catch {
                    print("【時間割】App Groupsからのデータ読み込みに失敗しました - \(error.localizedDescription)")
                }
            }
        }
    }

    /// キャッシュされた時間割データを取得
    func getCachedTimetableData() -> [String: [String: CourseModel]]? {
        return cachedTimetableData
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
        let expiryDate = Calendar.current.date(byAdding: .hour, value: 48, to: Date())!

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
            saveTimetableDataToAppGroup(timetableData)

            // ウィジェットを更新
            WidgetCenter.shared.reloadTimelines(ofKind: "TimetableWidget")
        }
    }

    /// 保存されている部屋変更情報を読み込む
    private func loadRoomChanges() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "roomChanges") {
            do {
                let decoder = JSONDecoder()
                let loadedChanges = try decoder.decode([String: RoomChange].self, from: data)

                // 期限切れの部屋変更を除外
                let now = Date()
                roomChanges = loadedChanges.filter { $0.value.expiryDate > now }

                print("【時間割】部屋変更情報を読み込みました（\(roomChanges.count)件）")

                // 期限切れのエントリが削除された場合は保存し直す
                if roomChanges.count != loadedChanges.count {
                    saveRoomChanges()
                }
            } catch {
                print("【時間割】部屋変更情報の読み込みに失敗: \(error.localizedDescription)")
                roomChanges = [:]
            }
        }
    }

    /// 部屋変更情報を保存する
    private func saveRoomChanges() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(roomChanges)
            UserDefaults.standard.set(data, forKey: "roomChanges")
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
                saveTimetableDataToAppGroup(timetableData)
            }
        }
    }
}

// 時間割関連のエラー定義
enum TimetableError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case invalidResponse
    case dataParsingFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "ユーザー認証が必要です"
        case .invalidEndpoint:
            return "APIエンドポイントが無効です"
        case .requestCreationFailed:
            return "リクエストデータの作成に失敗しました"
        case .noDataReceived:
            return "データが受信できませんでした"
        case .decodingFailed:
            return "レスポンスのデコードに失敗しました"
        case .invalidResponse:
            return "レスポンスの解析に失敗しました"
        case .dataParsingFailed:
            return "データの解析に失敗しました"
        case .apiError(let message):
            return "APIエラー: \(message)"
        }
    }
}
