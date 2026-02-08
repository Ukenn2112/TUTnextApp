import Foundation

/// Bus mock data for previews and testing
public enum MockBus {
    public static let sampleTimeEntries: [BusTimeEntry] = [
        BusTimeEntry(hour: 7, minute: 30),
        BusTimeEntry(hour: 7, minute: 45),
        BusTimeEntry(hour: 8, minute: 0)
    ]
    
    public static let sampleHourSchedule = BusHourSchedule(
        hour: 7,
        times: [
            BusTimeEntry(hour: 7, minute: 30),
            BusTimeEntry(hour: 7, minute: 45)
        ]
    )
    
    public static let sampleDaySchedule = BusDaySchedule(
        routeType: .fromSeisekiToSchool,
        scheduleType: .weekday,
        hourSchedules: [
            BusHourSchedule(hour: 6, times: [BusTimeEntry(hour: 6, minute: 30)]),
            BusHourSchedule(hour: 7, times: [
                BusTimeEntry(hour: 7, minute: 0),
                BusTimeEntry(hour: 7, minute: 30),
                BusTimeEntry(hour: 7, minute: 45)
            ]),
            BusHourSchedule(hour: 8, times: [
                BusTimeEntry(hour: 8, minute: 0),
                BusTimeEntry(hour: 8, minute: 30)
            ])
        ]
    )
    
    public static let sampleSpecialNote = BusSpecialNote(
        symbol: "◯",
        description: "学生専用便"
    )
    
    public static let sampleTemporaryMessage = BusTemporaryMessage(
        title: "本日の運行について",
        url: "https://tut.example.com/bus/info"
    )
    
    public static let sampleBusSchedule = BusSchedule(
        weekdaySchedules: [
            BusDaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: .weekday,
                hourSchedules: [
                    BusHourSchedule(hour: 6, times: [BusTimeEntry(hour: 6, minute: 30)]),
                    BusHourSchedule(hour: 7, times: [
                        BusTimeEntry(hour: 7, minute: 0),
                        BusTimeEntry(hour: 7, minute: 30)
                    ])
                ]
            ),
            BusDaySchedule(
                routeType: .fromNagayamaToSchool,
                scheduleType: .weekday,
                hourSchedules: [
                    BusHourSchedule(hour: 7, times: [
                        BusTimeEntry(hour: 7, minute: 20),
                        BusTimeEntry(hour: 7, minute: 40)
                    ])
                ]
            ),
            BusDaySchedule(
                routeType: .fromSchoolToSeiseki,
                scheduleType: .weekday,
                hourSchedules: [
                    BusHourSchedule(hour: 17, times: [
                        BusTimeEntry(hour: 17, minute: 10),
                        BusTimeEntry(hour: 17, minute: 40)
                    ])
                ]
            ),
            BusDaySchedule(
                routeType: .fromSchoolToNagayama,
                scheduleType: .weekday,
                hourSchedules: [
                    BusHourSchedule(hour: 17, times: [
                        BusTimeEntry(hour: 17, minute: 20),
                        BusTimeEntry(hour: 17, minute: 50)
                    ])
                ]
            )
        ],
        saturdaySchedules: [],
        wednesdaySchedules: [],
        specialNotes: [sampleSpecialNote],
        temporaryMessages: nil,
        pinMessage: nil
    )
}
