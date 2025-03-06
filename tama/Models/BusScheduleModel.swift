import Foundation

// MARK: - バス時刻表データモデル
struct BusSchedule {
    // MARK: - 列挙型
    
    /// バス路線タイプ
    enum RouteType {
        case fromSeisenToNagayama   // 聖蹟桜ヶ丘駅発
        case fromNagayamaToSeisen   // 永山駅発
        case fromSchoolToNagayama   // 学校発聖蹟桜ヶ丘駅行
        case fromNagayamaToSchool   // 永山駅行
    }
    
    /// バス時刻表タイプ
    enum ScheduleType {
        case weekday    // 平日（水曜日を除く）
        case saturday   // 土曜日
        case wednesday  // 水曜日特別ダイヤ
    }
    
    // MARK: - 構造体
    
    /// 個別の時刻データ
    struct TimeEntry: Equatable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool         // 特別便かどうか（◯や*などのマーク）
        let specialNote: String?    // 特別便の備考
        
        /// 時間を文字列にフォーマット (HH:MM)
        var formattedTime: String {
            return String(format: "%02d:%02d", hour, minute)
        }
        
        /// Equatableプロトコルの実装
        static func == (lhs: TimeEntry, rhs: TimeEntry) -> Bool {
            return lhs.hour == rhs.hour && 
                   lhs.minute == rhs.minute && 
                   lhs.isSpecial == rhs.isSpecial && 
                   lhs.specialNote == rhs.specialNote
        }
    }
    
    /// 1時間ごとの発車時刻
    struct HourSchedule {
        let hour: Int
        let times: [TimeEntry]
    }
    
    /// 1日の完全な時刻表
    struct DaySchedule {
        let routeType: RouteType
        let scheduleType: ScheduleType
        let hourSchedules: [HourSchedule]
    }
    
    /// 特別便の説明
    struct SpecialNote {
        let symbol: String
        let description: String
    }
    
    // MARK: - プロパティ
    
    /// すべての路線の時刻表
    let weekdaySchedules: [DaySchedule]    // 平日時刻表
    let saturdaySchedules: [DaySchedule]   // 土曜日時刻表
    let wednesdaySchedules: [DaySchedule]  // 水曜日時刻表
    let specialNotes: [SpecialNote]        // 特別便の説明
}

// MARK: - バス時刻表データ提供サービス
class BusScheduleService {
    /// シングルトンインスタンス
    static let shared = BusScheduleService()
    
    /// プライベートイニシャライザ（シングルトンパターン）
    private init() {}
    
    /// バス時刻表データを取得
    func getBusScheduleData() -> BusSchedule {
        // 平日時刻表 - 聖蹟桜ヶ丘駅発
        let weekdayFromSeisenSchedule = createWeekdayFromSeisenSchedule()
        
        // 平日時刻表 - 永山駅発
        let weekdayFromNagayamaSchedule = createWeekdayFromNagayamaSchedule()
        
        // 平日時刻表 - 中学・高校、大学発
        let weekdayFromSchoolSchedule = createWeekdayFromSchoolSchedule()
        
        // 平日時刻表 - 永山駅行
        let weekdayToNagayamaSchedule = createWeekdayToNagayamaSchedule()
        
        // 土曜日時刻表 - 聖蹟桜ヶ丘駅発
        let saturdayFromSeisenSchedule = createSaturdayFromSeisenSchedule()
        
        // 水曜日時刻表 - 聖蹟桜ヶ丘駅発（特別ダイヤ）
        let wednesdayFromSeisenSchedule = createWednesdayFromSeisenSchedule()
        
        // 水曜日時刻表 - 永山駅発（特別ダイヤ）
        let wednesdayFromNagayamaSchedule = createWednesdayFromNagayamaSchedule()
        
        // 水曜日時刻表 - 中学・高校、大学発（特別ダイヤ）
        let wednesdayFromSchoolSchedule = createWednesdayFromSchoolSchedule()
        
        // 水曜日時刻表 - 永山駅行（特別ダイヤ）
        let wednesdayToNagayamaSchedule = createWednesdayToNagayamaSchedule()
        
        // 特別便の説明
        let specialNotes = createSpecialNotes()
        
        return BusSchedule(
            weekdaySchedules: [
                weekdayFromSeisenSchedule,
                weekdayFromNagayamaSchedule,
                weekdayFromSchoolSchedule,
                weekdayToNagayamaSchedule
            ],
            saturdaySchedules: [
                saturdayFromSeisenSchedule
                // 他の土曜日時刻表を追加
            ],
            wednesdaySchedules: [
                wednesdayFromSeisenSchedule,
                wednesdayFromNagayamaSchedule,
                wednesdayFromSchoolSchedule,
                wednesdayToNagayamaSchedule
            ],
            specialNotes: specialNotes
        )
    }
    
    // MARK: - 平日時刻表作成メソッド
    
    /// 平日時刻表 - 聖蹟桜ヶ丘駅発
    private func createWeekdayFromSeisenSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromSeisenToNagayama,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: [
                    BusSchedule.TimeEntry(hour: 7, minute: 25, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 8, minute: 35, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 9, times: [
                    BusSchedule.TimeEntry(hour: 9, minute: 15, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 10, times: [
                    BusSchedule.TimeEntry(hour: 10, minute: 0, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 11, times: [
                    BusSchedule.TimeEntry(hour: 11, minute: 40, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 25, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 10, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 14, times: [
                    BusSchedule.TimeEntry(hour: 14, minute: 10, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 15, times: [
                    BusSchedule.TimeEntry(hour: 15, minute: 10, isSpecial: false, specialNote: nil)
                ])
            ]
        )
    }
    
    /// 平日時刻表 - 永山駅発
    private func createWeekdayFromNagayamaSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSeisen,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: []),
                BusSchedule.HourSchedule(hour: 8, times: []),
                BusSchedule.HourSchedule(hour: 9, times: [
                    BusSchedule.TimeEntry(hour: 9, minute: 45, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 10, times: [
                    BusSchedule.TimeEntry(hour: 10, minute: 5, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 40, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 11, times: [
                    BusSchedule.TimeEntry(hour: 11, minute: 30, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 12, minute: 20, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 12, minute: 30, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 13, times: []),
                BusSchedule.HourSchedule(hour: 14, times: [
                    BusSchedule.TimeEntry(hour: 14, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 14, minute: 40, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 14, minute: 45, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 15, times: [
                    BusSchedule.TimeEntry(hour: 15, minute: 15, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 15, minute: 45, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 16, minute: 5, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 16, minute: 15, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 16, minute: 30, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 45, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 18, times: [
                    BusSchedule.TimeEntry(hour: 18, minute: 0, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 18, minute: 35, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 18, minute: 40, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 19, times: [
                    BusSchedule.TimeEntry(hour: 19, minute: 40, isSpecial: true, specialNote: "M")
                ])
            ]
        )
    }
    
    /// 平日時刻表 - 中学・高校、大学発
    private func createWeekdayFromSchoolSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromSchoolToNagayama,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: []),
                BusSchedule.HourSchedule(hour: 8, times: []),
                BusSchedule.HourSchedule(hour: 9, times: []),
                BusSchedule.HourSchedule(hour: 10, times: [
                    BusSchedule.TimeEntry(hour: 10, minute: 10, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 15, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 25, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 35, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 40, isSpecial: false, specialNote: nil),
                    BusSchedule.TimeEntry(hour: 10, minute: 50, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 11, times: []),
                BusSchedule.HourSchedule(hour: 12, times: []),
                BusSchedule.HourSchedule(hour: 13, times: []),
                BusSchedule.HourSchedule(hour: 14, times: []),
                BusSchedule.HourSchedule(hour: 15, times: []),
                BusSchedule.HourSchedule(hour: 16, times: []),
                BusSchedule.HourSchedule(hour: 17, times: []),
                BusSchedule.HourSchedule(hour: 18, times: []),
                BusSchedule.HourSchedule(hour: 19, times: [])
            ]
        )
    }
    
    /// 平日時刻表 - 永山駅行
    private func createWeekdayToNagayamaSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSchool,
            scheduleType: .weekday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: []),
                BusSchedule.HourSchedule(hour: 8, times: []),
                BusSchedule.HourSchedule(hour: 9, times: []),
                BusSchedule.HourSchedule(hour: 10, times: []),
                BusSchedule.HourSchedule(hour: 11, times: []),
                BusSchedule.HourSchedule(hour: 12, times: []),
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 0, isSpecial: true, specialNote: "*"),
                    BusSchedule.TimeEntry(hour: 13, minute: 50, isSpecial: true, specialNote: "*")
                ]),
                BusSchedule.HourSchedule(hour: 14, times: [
                    BusSchedule.TimeEntry(hour: 14, minute: 50, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 15, times: []),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 5, isSpecial: true, specialNote: "*"),
                    BusSchedule.TimeEntry(hour: 16, minute: 25, isSpecial: true, specialNote: "*"),
                    BusSchedule.TimeEntry(hour: 16, minute: 45, isSpecial: true, specialNote: "*")
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 15, isSpecial: true, specialNote: "*"),
                    BusSchedule.TimeEntry(hour: 17, minute: 50, isSpecial: true, specialNote: "*")
                ]),
                BusSchedule.HourSchedule(hour: 18, times: [
                    BusSchedule.TimeEntry(hour: 18, minute: 5, isSpecial: true, specialNote: "*"),
                    BusSchedule.TimeEntry(hour: 18, minute: 40, isSpecial: true, specialNote: "*")
                ]),
                BusSchedule.HourSchedule(hour: 19, times: [])
            ]
        )
    }
    
    // MARK: - 土曜日時刻表作成メソッド
    
    /// 土曜日時刻表 - 聖蹟桜ヶ丘駅発
    private func createSaturdayFromSeisenSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromSeisenToNagayama,
            scheduleType: .saturday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: [
                    BusSchedule.TimeEntry(hour: 7, minute: 25, isSpecial: false, specialNote: nil)
                ]),
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 0, isSpecial: true, specialNote: "◯"),
                    BusSchedule.TimeEntry(hour: 8, minute: 25, isSpecial: true, specialNote: "◯"),
                    BusSchedule.TimeEntry(hour: 8, minute: 55, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 9, times: [
                    BusSchedule.TimeEntry(hour: 9, minute: 25, isSpecial: true, specialNote: "◯"),
                    BusSchedule.TimeEntry(hour: 9, minute: 55, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 10, times: [
                    BusSchedule.TimeEntry(hour: 10, minute: 25, isSpecial: true, specialNote: "◯"),
                    BusSchedule.TimeEntry(hour: 10, minute: 55, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 11, times: [
                    BusSchedule.TimeEntry(hour: 11, minute: 55, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 50, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 20, isSpecial: true, specialNote: "◯")
                ]),
                BusSchedule.HourSchedule(hour: 14, times: [
                    BusSchedule.TimeEntry(hour: 14, minute: 25, isSpecial: true, specialNote: "◯")
                ])
            ]
        )
    }
    
    // MARK: - 水曜日時刻表作成メソッド
    
    /// 水曜日時刻表 - 聖蹟桜ヶ丘駅発（特別ダイヤ）
    private func createWednesdayFromSeisenSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromSeisenToNagayama,
            scheduleType: .wednesday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 7, times: [
                    BusSchedule.TimeEntry(hour: 7, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 10, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 8, minute: 45, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 9, times: [
                    BusSchedule.TimeEntry(hour: 9, minute: 20, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 15, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 0, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 15, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 20, times: [
                    BusSchedule.TimeEntry(hour: 20, minute: 10, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 21, times: [
                    BusSchedule.TimeEntry(hour: 21, minute: 10, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 21, minute: 20, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 21, minute: 30, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 21, minute: 52, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 22, times: [
                    BusSchedule.TimeEntry(hour: 22, minute: 0, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 22, minute: 5, isSpecial: true, specialNote: "W"),
                ])
            ]
        )
    }
    
    /// 水曜日時刻表 - 永山駅発（特別ダイヤ）
    private func createWednesdayFromNagayamaSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSeisen,
            scheduleType: .wednesday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 8, times: [
                    BusSchedule.TimeEntry(hour: 8, minute: 0, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 9, times: [
                    BusSchedule.TimeEntry(hour: 9, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 45, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 0, isSpecial: true, specialNote: "W"),
                    BusSchedule.TimeEntry(hour: 16, minute: 45, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 18, times: [
                    BusSchedule.TimeEntry(hour: 18, minute: 15, isSpecial: true, specialNote: "W")
                ])
            ]
        )
    }
    
    /// 水曜日時刻表 - 中学・高校、大学発（特別ダイヤ）
    private func createWednesdayFromSchoolSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromSchoolToNagayama,
            scheduleType: .wednesday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 12, times: [
                    BusSchedule.TimeEntry(hour: 12, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 15, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 15, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 0, isSpecial: true, specialNote: "W")
                ])
            ]
        )
    }
    
    /// 水曜日時刻表 - 永山駅行（特別ダイヤ）
    private func createWednesdayToNagayamaSchedule() -> BusSchedule.DaySchedule {
        return BusSchedule.DaySchedule(
            routeType: .fromNagayamaToSchool,
            scheduleType: .wednesday,
            hourSchedules: [
                BusSchedule.HourSchedule(hour: 13, times: [
                    BusSchedule.TimeEntry(hour: 13, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 16, times: [
                    BusSchedule.TimeEntry(hour: 16, minute: 0, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 17, times: [
                    BusSchedule.TimeEntry(hour: 17, minute: 45, isSpecial: true, specialNote: "W")
                ])
            ]
        )
    }
    
    /// 特別便の説明を作成
    private func createSpecialNotes() -> [BusSchedule.SpecialNote] {
        return [
            BusSchedule.SpecialNote(symbol: "◯", description: "印の付いた便は、永山駅経由学校行です。"),
            BusSchedule.SpecialNote(symbol: "*", description: "印のついた便は、永山駅経由聖蹟桜ヶ丘駅行です。"),
            BusSchedule.SpecialNote(symbol: "M", description: "大学生用マイクロバス（火・木のみ）"),
            BusSchedule.SpecialNote(symbol: "W", description: "水曜日特別ダイヤ")
        ]
    }
}
