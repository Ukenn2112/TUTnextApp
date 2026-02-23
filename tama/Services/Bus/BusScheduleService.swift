import Foundation
import SwiftData
import SwiftUI

// MARK: - バス時刻表データ提供サービス

/// バス時刻表データ提供サービス
final class BusScheduleService {
    /// シングルトンインスタンス
    static let shared = BusScheduleService()

    /// APIエンドポイント
    private let apiURL = "https://tama.qaq.tw/bus/app_data"

    /// キャッシュされたバス時刻表データ
    private var cachedSchedule: BusSchedule?

    /// キャッシュの有効期限（秒）
    private let cacheExpirationTime: TimeInterval = 43_200  // 12時間

    /// 最後にデータを取得した時間
    private var lastFetchTime: Date?

    /// APIリクエストが現在進行中かどうか
    private var isRequestInProgress = false

    /// SwiftData ModelContext
    private var modelContext: ModelContext?

    /// プライベートイニシャライザ（シングルトンパターン）
    private init() {
        setupModelContext()
        // 保存されたデータがあれば読み込む
        loadCachedDataFromSwiftData()
    }

    /// ModelContext を初期化
    private func setupModelContext() {
        modelContext = ModelContext(SharedModelContainer.shared)
    }

    /// バス時刻表データを取得（非同期）
    /// キャッシュがあれば即座に返し、バックグラウンドでAPIから最新データを取得する。
    /// API取得成功時はcompletionを再度呼び出してデータを更新する。
    /// API取得失敗時はキャッシュが12時間以内なら何もしない。12時間を超えていればエラーを返す。
    func fetchBusScheduleData(completion: @escaping (BusSchedule?, Error?) -> Void) {
        // キャッシュがあれば先に返す（有効期限に関係なく）
        if let cachedSchedule = cachedSchedule {
            let lastFetch = lastFetchTime.map { formatDate($0) } ?? "不明"
            print("BusScheduleService: キャッシュデータを先行表示します（取得時間: \(lastFetch)）")
            completion(cachedSchedule, nil)
        }

        // リクエストが既に進行中の場合は重複を避ける
        if isRequestInProgress {
            print("BusScheduleService: リクエストが既に進行中です")
            return
        }

        print("BusScheduleService: バックグラウンドでAPIから最新データを取得します")
        isRequestInProgress = true

        guard let url = URL(string: apiURL) else {
            isRequestInProgress = false
            if !isCacheValid() {
                let error = NSError(
                    domain: "BusScheduleService", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                print("BusScheduleService: エラー（キャッシュ無効）- \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil, error) }
            }
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            defer { self.isRequestInProgress = false }

            if let error = error {
                print("BusScheduleService: ネットワークエラー - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !self.isCacheValid() {
                        print("BusScheduleService: キャッシュが12時間を超えているためエラーを返します")
                        completion(nil, error)
                    } else {
                        print("BusScheduleService: キャッシュが有効期限内のためエラーを無視します")
                    }
                }
                return
            }

            guard let data = data else {
                let error = NSError(
                    domain: "BusScheduleService", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"])
                print("BusScheduleService: データなし - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !self.isCacheValid() {
                        print("BusScheduleService: キャッシュが12時間を超えているためエラーを返します")
                        completion(nil, error)
                    } else {
                        print("BusScheduleService: キャッシュが有効期限内のためエラーを無視します")
                    }
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(BusAPIResponse.self, from: data)

                let busSchedule = self.createBusScheduleFromAPIResponse(apiResponse)

                // キャッシュを更新
                self.cachedSchedule = busSchedule
                self.lastFetchTime = Date()

                let fetchTime = self.lastFetchTime!
                print("BusScheduleService: 新しいデータの取得に成功しました（取得時間: \(self.formatDate(fetchTime))）")

                DispatchQueue.main.async {
                    self.saveBusDataToSwiftData(busSchedule: busSchedule, lastFetchTime: fetchTime)
                    // API成功時はデータを更新するため再度completionを呼ぶ
                    completion(busSchedule, nil)
                }
            } catch {
                print("BusScheduleService: デコードエラー - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if !self.isCacheValid() {
                        print("BusScheduleService: キャッシュが12時間を超えているためエラーを返します")
                        completion(nil, error)
                    } else {
                        print("BusScheduleService: キャッシュが有効期限内のためエラーを無視します")
                    }
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
            print(
                "BusScheduleService: 同期取得 - キャッシュされたデータを使用します（取得時間: \(formatDate(lastFetchTime))）")
            return cachedSchedule
        }

        print("BusScheduleService: 同期取得 - キャッシュが無効なためダミーデータを返します")
        // キャッシュがない場合はダミーデータを返す
        return createDummyBusSchedule()
    }

    /// キャッシュの有効性をチェック
    func isCacheValid() -> Bool {
        guard cachedSchedule != nil, let lastFetchTime = lastFetchTime else {
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
            temporaryMessages: response.messages,
            pin: response.pin
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
            daySchedules.append(
                BusSchedule.DaySchedule(
                    routeType: .fromSeisekiToSchool,
                    scheduleType: scheduleType,
                    hourSchedules: hourSchedules
                ))
        }

        // 永山駅発
        if let hourSchedules = fromNagayamaToSchool {
            daySchedules.append(
                BusSchedule.DaySchedule(
                    routeType: .fromNagayamaToSchool,
                    scheduleType: scheduleType,
                    hourSchedules: hourSchedules
                ))
        }

        // 聖蹟桜ヶ丘駅行
        if let hourSchedules = fromSchoolToSeiseki {
            daySchedules.append(
                BusSchedule.DaySchedule(
                    routeType: .fromSchoolToSeiseki,
                    scheduleType: scheduleType,
                    hourSchedules: hourSchedules
                ))
        }

        // 永山駅行
        if let hourSchedules = fromSchoolToNagayama {
            daySchedules.append(
                BusSchedule.DaySchedule(
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
            BusSchedule.SpecialNote(
                symbol: "◎", description: NSLocalizedString("印の付いた便は、永山駅経由学校行です。", comment: "")),
            BusSchedule.SpecialNote(
                symbol: "*", description: NSLocalizedString("印のついた便は、永山駅経由聖蹟桜ヶ丘駅行です。", comment: "")),
            BusSchedule.SpecialNote(
                symbol: "C", description: NSLocalizedString("中学生乗車限定", comment: "")),
            BusSchedule.SpecialNote(
                symbol: "K", description: NSLocalizedString("高校生乗車限定", comment: "")),
            BusSchedule.SpecialNote(
                symbol: "M", description: NSLocalizedString("大学生用マイクロバス（月～木のみ）", comment: ""))
        ]
    }

    /// ダミーのバス時刻表データを作成（APIからデータを取得できない場合のフォールバック）
    private func createDummyBusSchedule() -> BusSchedule {
        // 平日時刻表 - 聖蹟桜ヶ丘駅発
        let weekdayFromSeisekiSchedule = BusSchedule.DaySchedule(
            routeType: .fromSeisekiToSchool,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(
                    hour: 8,
                    times: [
                        BusSchedule.TimeEntry(
                            hour: 8, minute: 0, isSpecial: false, specialNote: nil),
                        BusSchedule.TimeEntry(
                            hour: 8, minute: 35, isSpecial: false, specialNote: nil)
                    ])
            ]
        )

        // 平日時刻表 - 永山駅発
        let weekdayFromNagayamaSchedule = BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSchool,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(
                    hour: 8,
                    times: [
                        BusSchedule.TimeEntry(
                            hour: 8, minute: 20, isSpecial: false, specialNote: nil)
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
            temporaryMessages: nil,
            pin: nil
        )
    }

    /// SwiftData にバスデータを保存
    private func saveBusDataToSwiftData(busSchedule: BusSchedule, lastFetchTime: Date) {
        guard let context = modelContext else { return }

        do {
            let busData = try JSONEncoder().encode(busSchedule)

            // 既存レコードを検索
            let descriptor = FetchDescriptor<CachedBusSchedule>(
                predicate: #Predicate { $0.key == "busSchedule" }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.data = busData
                existing.lastFetchTime = lastFetchTime
            } else {
                let record = CachedBusSchedule(data: busData, lastFetchTime: lastFetchTime)
                context.insert(record)
            }

            try context.save()
            print("BusScheduleService: SwiftData にデータを保存しました")
        } catch {
            print("BusScheduleService: SwiftData への保存に失敗しました - \(error.localizedDescription)")
        }
    }

    /// SwiftData からキャッシュされたデータを読み込む
    private func loadCachedDataFromSwiftData() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<CachedBusSchedule>(
                predicate: #Predicate { $0.key == "busSchedule" }
            )
            if let cached = try context.fetch(descriptor).first {
                let busSchedule = try JSONDecoder().decode(BusSchedule.self, from: cached.data)
                self.cachedSchedule = busSchedule
                self.lastFetchTime = cached.lastFetchTime
                print(
                    "BusScheduleService: SwiftData からデータを読み込みました（取得時間: \(self.formatDate(cached.lastFetchTime))）"
                )
            }
        } catch {
            print(
                "BusScheduleService: SwiftData からの読み込みに失敗しました - \(error.localizedDescription)"
            )
        }
    }
}
