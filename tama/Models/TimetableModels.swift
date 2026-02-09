import SwiftUI

/// 時間割のコマ（時限 x 曜日）を表すモデル
struct TimeSlot: Identifiable {
    let id = UUID()
    let period: Int
    let dayOfWeek: Int
    var course: Course?
}

/// 時間割で使用する簡易コースモデル
struct Course: Identifiable {
    let id = UUID()
    let name: String
    let room: String
    let color: Color
    var unfinishedTasks: Int
}

/// 時間割上のコース表示用モデル
struct TimetableCourse {
    let name: String
    let room: String
    let teacher: String
    let startTime: String
    let endTime: String
    var colorIndex: Int = 1
}
