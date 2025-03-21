import Foundation

// MARK: - バス時刻表データ提供サービス
class BusScheduleService {
    /// シングルトンインスタンス
    static let shared = BusScheduleService()
    
    /// APIエンドポイント
    private let apiURL = "https://tama.qaq.tw/bus/app_data"
    
    /// キャッシュされたバス時刻表データ
    private var cachedSchedule: BusSchedule?
    
    /// キャッシュの有効期限（秒）
    private let cacheExpirationTime: TimeInterval = 3600 // 1時間
    
    /// 最後にデータを取得した時間
    private var lastFetchTime: Date?
    
    /// APIリクエストが現在進行中かどうか
    private var isRequestInProgress = false
    
    /// プライベートイニシャライザ（シングルトンパターン）
    private init() {}
    
    /// バス時刻表データを取得（非同期）
    func fetchBusScheduleData(completion: @escaping (BusSchedule?, Error?) -> Void) {
        // リクエストが進行中の場合は、重複リクエストを避ける
        if isRequestInProgress {
            print("BusScheduleService: リクエストが既に進行中です")
            return
        }
        
        // キャッシュが有効な場合はキャッシュを返す
        if let cachedSchedule = cachedSchedule, 
           let lastFetchTime = lastFetchTime,
           Date().timeIntervalSince(lastFetchTime) < cacheExpirationTime {
            print("BusScheduleService: キャッシュされたデータを使用します（取得時間: \(formatDate(lastFetchTime))）")
            completion(cachedSchedule, nil)
            return
        }
        
        print("BusScheduleService: APIから新しいデータを取得します")
        isRequestInProgress = true
        
        // APIからデータを取得
        guard let url = URL(string: apiURL) else {
            let error = NSError(domain: "BusScheduleService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            print("BusScheduleService: エラー - \(error.localizedDescription)")
            isRequestInProgress = false
            completion(nil, error)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // データ取得完了後、進行中フラグをリセット
            defer {
                self.isRequestInProgress = false
            }
            
            if let error = error {
                print("BusScheduleService: ネットワークエラー - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "BusScheduleService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                print("BusScheduleService: エラー - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(BusAPIResponse.self, from: data)
                
                // APIレスポンスからBusScheduleオブジェクトを作成
                let busSchedule = self.createBusScheduleFromAPIResponse(apiResponse)
        
                // キャッシュを更新
                self.cachedSchedule = busSchedule
                self.lastFetchTime = Date()
                
                print("BusScheduleService: 新しいデータの取得に成功しました（取得時間: \(self.formatDate(self.lastFetchTime!))）")
                
                DispatchQueue.main.async {
                    completion(busSchedule, nil)
                }
            } catch {
                print("BusScheduleService: デコードエラー - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// 同期的にバス時刻表データを取得（既存のコードとの互換性のため）
    func getBusScheduleData() -> BusSchedule {
        // キャッシュが有効な場合はキャッシュを返す
        if let cachedSchedule = cachedSchedule, 
           let lastFetchTime = lastFetchTime,
           Date().timeIntervalSince(lastFetchTime) < cacheExpirationTime {
            print("BusScheduleService: 同期取得 - キャッシュされたデータを使用します（取得時間: \(formatDate(lastFetchTime))）")
            return cachedSchedule
        }
        
        print("BusScheduleService: 同期取得 - キャッシュが無効なためダミーデータを返します")
        // キャッシュがない場合はダミーデータを返す
        return createDummyBusSchedule()
    }
    
    /// キャッシュの有効性をチェック
    func isCacheValid() -> Bool {
        guard let _ = cachedSchedule, let lastFetchTime = lastFetchTime else {
            return false
        }
        
        return Date().timeIntervalSince(lastFetchTime) < cacheExpirationTime
    }
    
    /// 日付をフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // MARK: - プライベートヘルパーメソッド
    
    /// APIレスポンスからBusScheduleオブジェクトを作成
    private func createBusScheduleFromAPIResponse(_ response: BusAPIResponse) -> BusSchedule {
        // 平日時刻表
        let weekdaySchedules = createDaySchedules(
            fromSeisekiToSchool: response.data.weekday.fromSeisekiToSchool,
            fromNagayamaToSchool: response.data.weekday.fromNagayamaToSchool,
            fromSchoolToSeiseki: response.data.weekday.fromSchoolToSeiseki,
            fromSchoolToNagayama: response.data.weekday.fromSchoolToNagayama,
            scheduleType: .weekday
        )
        
        // 水曜日時刻表
        let wednesdaySchedules = createDaySchedules(
            fromSeisekiToSchool: response.data.wednesday.fromSeisekiToSchool,
            fromNagayamaToSchool: response.data.wednesday.fromNagayamaToSchool,
            fromSchoolToSeiseki: response.data.wednesday.fromSchoolToSeiseki,
            fromSchoolToNagayama: response.data.wednesday.fromSchoolToNagayama,
            scheduleType: .wednesday
        )
        
        // 土曜日時刻表
        let saturdaySchedules = createDaySchedules(
            fromSeisekiToSchool: response.data.saturday.fromSeisekiToSchool,
            fromNagayamaToSchool: response.data.saturday.fromNagayamaToSchool,
            fromSchoolToSeiseki: response.data.saturday.fromSchoolToSeiseki,
            fromSchoolToNagayama: response.data.saturday.fromSchoolToNagayama,
            scheduleType: .saturday
        )
        
        // 特別便の説明
        let specialNotes = createSpecialNotes()
        
        return BusSchedule(
            weekdaySchedules: weekdaySchedules,
            saturdaySchedules: saturdaySchedules,
            wednesdaySchedules: wednesdaySchedules,
            specialNotes: specialNotes,
            temporaryMessages: response.messages
        )
    }
    
    /// 各路線タイプの時刻表からDayScheduleの配列を作成
    private func createDaySchedules(
        fromSeisekiToSchool: [BusSchedule.HourSchedule]?,
        fromNagayamaToSchool: [BusSchedule.HourSchedule]?,
        fromSchoolToSeiseki: [BusSchedule.HourSchedule]?,
        fromSchoolToNagayama: [BusSchedule.HourSchedule]?,
        scheduleType: BusSchedule.ScheduleType
    ) -> [BusSchedule.DaySchedule] {
        var daySchedules: [BusSchedule.DaySchedule] = []
        
        // 聖蹟桜ヶ丘駅発
        if let hourSchedules = fromSeisekiToSchool {
            daySchedules.append(BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: scheduleType,
                hourSchedules: hourSchedules
            ))
        }
        
        // 永山駅発
        if let hourSchedules = fromNagayamaToSchool {
            daySchedules.append(BusSchedule.DaySchedule(
                routeType: .fromNagayamaToSchool,
                scheduleType: scheduleType,
                hourSchedules: hourSchedules
            ))
        }
        
        // 聖蹟桜ヶ丘駅行
        if let hourSchedules = fromSchoolToSeiseki {
            daySchedules.append(BusSchedule.DaySchedule(
                routeType: .fromSchoolToSeiseki,
                scheduleType: scheduleType,
                hourSchedules: hourSchedules
            ))
        }
        
        // 永山駅行
        if let hourSchedules = fromSchoolToNagayama {
            daySchedules.append(BusSchedule.DaySchedule(
                routeType: .fromSchoolToNagayama,
                scheduleType: scheduleType,
                hourSchedules: hourSchedules
            ))
        }
        
        return daySchedules
    }
    
    /// 特別便の説明を作成
    private func createSpecialNotes() -> [BusSchedule.SpecialNote] {
        return [
            BusSchedule.SpecialNote(symbol: "◯", description: NSLocalizedString("印の付いた便は、永山駅経由学校行です。", comment: "")),
            BusSchedule.SpecialNote(symbol: "*", description: NSLocalizedString("印のついた便は、永山駅経由聖蹟桜ヶ丘駅行です。", comment: "")),
            BusSchedule.SpecialNote(symbol: "C", description: NSLocalizedString("中学生乗車限定", comment: "")),
            BusSchedule.SpecialNote(symbol: "K", description: NSLocalizedString("高校生乗車限定", comment: "")),
            BusSchedule.SpecialNote(symbol: "M", description: NSLocalizedString("大学生用マイクロバス（火・水・木のみ）", comment: ""))
        ]
    }
    
    /// ダミーのバス時刻表データを作成（APIからデータを取得できない場合のフォールバック）
    private func createDummyBusSchedule() -> BusSchedule {
        // 平日時刻表 - 聖蹟桜ヶ丘駅発
        let weekdayFromSeisekiSchedule = BusSchedule.DaySchedule(
            routeType: .fromSeisekiToSchool,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 8, minute: 35, isSpecial: false, specialNote: nil)
                ])
            ]
        )
        
        // 平日時刻表 - 永山駅発
        let weekdayFromNagayamaSchedule = BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSchool,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 20, isSpecial: false, specialNote: nil)
                ])
            ]
        )
        
        // 特別便の説明
        let specialNotes = createSpecialNotes()
        
        return BusSchedule(
            weekdaySchedules: [weekdayFromSeisekiSchedule, weekdayFromNagayamaSchedule],
            saturdaySchedules: [],
            wednesdaySchedules: [],
            specialNotes: specialNotes,
            temporaryMessages: nil
        )
    }
} 
