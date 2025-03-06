import Foundation

// 校车时刻表数据模型
struct BusSchedule {
    // 校车路线类型
    enum RouteType {
        case fromSeisenToNagayama
        case fromNagayamaToSeisen
        case fromSchoolToNagayama
        case fromNagayamaToSchool
    }
    
    // 校车时刻表类型
    enum ScheduleType {
        case weekday
        case saturday
        case wednesday // 追加水曜日スケジュールタイプ
    }
    
    // 单个时刻数据
    struct TimeEntry: Equatable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool // 标记特殊班次（如◯或*标记）
        let specialNote: String? // 特殊班次的备注
        
        // 格式化时间为字符串 (HH:MM)
        var formattedTime: String {
            return String(format: "%02d:%02d", hour, minute)
        }
        
        // Equatableプロトコルの実装
        static func == (lhs: TimeEntry, rhs: TimeEntry) -> Bool {
            return lhs.hour == rhs.hour && 
                   lhs.minute == rhs.minute && 
                   lhs.isSpecial == rhs.isSpecial && 
                   lhs.specialNote == rhs.specialNote
        }
    }
    
    // 单个小时的所有发车时间
    struct HourSchedule {
        let hour: Int
        let times: [TimeEntry]
    }
    
    // 完整的一天时刻表
    struct DaySchedule {
        let routeType: RouteType
        let scheduleType: ScheduleType
        let hourSchedules: [HourSchedule]
    }
    
    // 特殊班次说明
    struct SpecialNote {
        let symbol: String
        let description: String
    }
    
    // 所有路线的时刻表
    let weekdaySchedules: [DaySchedule]
    let saturdaySchedules: [DaySchedule]
    let wednesdaySchedules: [DaySchedule] // 追加水曜日スケジュール
    let specialNotes: [SpecialNote]
}

// 校车时刻表数据提供服务
class BusScheduleService {
    static let shared = BusScheduleService()
    
    private init() {}
    
    // 获取校车时刻表数据
    func getBusScheduleData() -> BusSchedule {
        // 平日时刻表 - 聖蹟桜ヶ丘駅発
        let weekdayFromSeisenSchedule = BusSchedule.DaySchedule(
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
        
        // 平日时刻表 - 永山駅発
        let weekdayFromNagayamaSchedule = BusSchedule.DaySchedule(
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
        
        // 平日时刻表 - 中学・高校、大学発
        let weekdayFromSchoolSchedule = BusSchedule.DaySchedule(
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
        
        // 平日时刻表 - 永山駅行
        let weekdayToNagayamaSchedule = BusSchedule.DaySchedule(
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
        
        // 周六时刻表数据（根据图片内容添加）
        // 这里只是示例，您需要根据实际时刻表填充完整数据
        let saturdayFromSeisenSchedule = BusSchedule.DaySchedule(
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
        
        // 水曜日時刻表 - 聖蹟桜ヶ丘駅発（特別ダイヤ）
        let wednesdayFromSeisenSchedule = BusSchedule.DaySchedule(
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
                    BusSchedule.TimeEntry(hour: 21, minute: 30, isSpecial: true, specialNote: "W")
                ]),
                BusSchedule.HourSchedule(hour: 22, times: [
                    BusSchedule.TimeEntry(hour: 22, minute: 0, isSpecial: true, specialNote: "W")
                ])
            ]
        )
        
        // 水曜日時刻表 - 永山駅発（特別ダイヤ）
        let wednesdayFromNagayamaSchedule = BusSchedule.DaySchedule(
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
        
        // 水曜日時刻表 - 中学・高校、大学発（特別ダイヤ）
        let wednesdayFromSchoolSchedule = BusSchedule.DaySchedule(
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
        
        // 水曜日時刻表 - 永山駅行（特別ダイヤ）
        let wednesdayToNagayamaSchedule = BusSchedule.DaySchedule(
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
        
        // 特殊班次说明
        let specialNotes = [
            BusSchedule.SpecialNote(symbol: "◯", description: "印の付いた便は、永山駅経由学校行です。"),
            BusSchedule.SpecialNote(symbol: "*", description: "印のついた便は、永山駅経由聖蹟桜ヶ丘駅行です。"),
            BusSchedule.SpecialNote(symbol: "M", description: "大学生用マイクロバス（火・木のみ）"),
            BusSchedule.SpecialNote(symbol: "W", description: "水曜日特別ダイヤ")
        ]
        
        return BusSchedule(
            weekdaySchedules: [
                weekdayFromSeisenSchedule,
                weekdayFromNagayamaSchedule,
                weekdayFromSchoolSchedule,
                weekdayToNagayamaSchedule
            ],
            saturdaySchedules: [
                saturdayFromSeisenSchedule
                // 添加其他周六时刻表
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
}
