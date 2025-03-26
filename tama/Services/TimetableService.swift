import Foundation
import SwiftUI

class TimetableService {
    static let shared = TimetableService()
    
    /// App Group ID
    private let appGroupID = "group.com.meikenn.tama"
    
    /// キャッシュされた時間割データ
    private var cachedTimetableData: [String: [String: CourseModel]]?
    
    /// 最後にデータを取得した時間
    private var lastFetchTime: Date?
    
    private init() {
        // 起動時にApp Groupsからデータを読み込む
        loadTimetableDataFromAppGroup()
    }
    
    // 時間割データを取得する関数
    func fetchTimetableData(completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void) {
        fetchTimetableData(semester: .current, completion: completion)
    }
    
    // 指定した学期の時間割データを取得する関数
    func fetchTimetableData(semester: Semester, completion: @escaping (Result<[String: [String: CourseModel]], Error>) -> Void) {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else {
            print("【時間割】ユーザー認証情報なし")
            completion(.failure(TimetableError.userNotAuthenticated))
            return
        }
        
        // API リクエストの準備
        guard let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/getJugyoKeijiMenuInfo") else {
            print("【時間割】無効なエンドポイント")
            completion(.failure(TimetableError.invalidEndpoint))
            return
        }
        
        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "plainLoginPassword": "",
            "data": [
                "kaikoNendo": semester.year,
                "gakkiNo": semester.termNo
            ],
            "langCd": "",
            "encryptedLoginPassword": encryptedPassword,
            "loginUserId": user.username,
            "productCd": "ap",
            "subProductCd": "apa"
        ]
        
        // リクエストデータをログに出力
        print("【時間割】リクエスト: \(url.absoluteString)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonStr = String(data: jsonString, encoding: .utf8) {
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
                .data(using: .utf8) else {
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
                   let success = statusDto["success"] as? Bool {
                    
                    print("【時間割】ステータス: success=\(success)")
                    
                    if success {
                        if let data = json["data"] as? [String: Any],
                           let courseList = data["jgkmDtoList"] as? [[String: Any]] {
                            print("【時間割】全未読揭示数: \(data["keijiCnt"] as? Int ?? 0)")
                            
                            // 時間割データの変換
                            let timetableData = self.convertToTimetableData(courseList)
                            
                            // データをApp Groupsに保存
                            self.saveTimetableDataToAppGroup(timetableData)
                            self.lastFetchTime = Date()
                            
                            // メモリ内のキャッシュも更新
                            self.cachedTimetableData = timetableData
                            
                            // 未読件数を更新してから時間割データを返す
                            UserService.shared.updateAllKeijiMidokCnt(keijiCnt: data["keijiCnt"] as? Int ?? 0) {
                                print("【時間割】変換後データ: \(timetableData.keys) 曜日, 合計\(timetableData.values.flatMap { $0.values }.count)コース")
                                completion(.success(timetableData))
                            }
                        } else {
                            print("【時間割】データ解析失敗")
                            completion(.failure(TimetableError.dataParsingFailed))
                        }
                    } else {
                        if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
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
    private func convertToTimetableData(_ courseList: [[String: Any]]) -> [String: [String: CourseModel]] {
        var timetableData: [String: [String: CourseModel]] = [:]
        
        // 曜日の変換マップ
        let weekdayMap = [
            1: NSLocalizedString("月", comment: ""),
            2: NSLocalizedString("火", comment: ""),
            3: NSLocalizedString("水", comment: ""),
            4: NSLocalizedString("木", comment: ""),
            5: NSLocalizedString("金", comment: ""),
            6: NSLocalizedString("土", comment: ""),
            7: NSLocalizedString("日", comment: "")
        ]
        
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
                  let keijiMidokCnt = courseData["keijiMidokCnt"] as? Int else {
                print("【時間割】コースデータの解析に失敗: \(courseData)")
                continue
            }
            
            // 曜日を取得
            guard let day = weekdayMap[weekdayNumber] else {
                print("【時間割】無効な曜日: \(weekdayNumber)")
                continue
            }
            
            // 時限を文字列に変換
            let period = "\(periodNumber)"
            
            // 保存されている色インデックスを取得、なければデフォルト値を使用
            let colorIndex = CourseColorService.shared.getCourseColor(jugyoCd: jugyoCd) ?? 1
            
            // CourseModelを作成
            let courseModel = CourseModel(
                name: courseName,
                room: roomName.replacingOccurrences(of: "教室", with: ""),
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
            
            // 時間割データに追加
            if timetableData[day] == nil {
                timetableData[day] = [:]
            }
            timetableData[day]?[period] = courseModel
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
               let fetchTime = userDefaults?.object(forKey: "lastTimetableFetchTime") as? Date {
                do {
                    let decoder = JSONDecoder()
                    let timetableDataDecoded = try decoder.decode([String: [String: CourseModel]].self, from: timetableData)
                    
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
