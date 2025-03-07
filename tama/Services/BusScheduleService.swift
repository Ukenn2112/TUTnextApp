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
    
    /// プライベートイニシャライザ（シングルトンパターン）
    private init() {}
    
    /// バス時刻表データを取得（非同期）
    func fetchBusScheduleData(completion: @escaping (BusSchedule?, Error?) -> Void) {
        // キャッシュが有効な場合はキャッシュを返す
        if let cachedSchedule = cachedSchedule, 
           let lastFetchTime = lastFetchTime,
           Date().timeIntervalSince(lastFetchTime) < cacheExpirationTime {
            completion(cachedSchedule, nil)
            return
        }
        
        // APIからデータを取得
        guard let url = URL(string: apiURL) else {
            completion(nil, NSError(domain: "BusScheduleService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "BusScheduleService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
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
                
                DispatchQueue.main.async {
                    completion(busSchedule, nil)
                }
            } catch {
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
            return cachedSchedule
        }
        
        // キャッシュがない場合はダミーデータを返す
        return createDummyBusSchedule()
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
            BusSchedule.SpecialNote(symbol: "◯", description: "印の付いた便は、永山駅経由学校行です。"),
            BusSchedule.SpecialNote(symbol: "*", description: "印のついた便は、永山駅経由聖蹟桜ヶ丘駅行です。"),
            BusSchedule.SpecialNote(symbol: "C", description: "中学生乗車限定"),
            BusSchedule.SpecialNote(symbol: "K", description: "高校生乗車限定"),
            BusSchedule.SpecialNote(symbol: "M", description: "大学生用マイクロバス（火・水・木のみ）")
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