import SwiftUI

// 课程模型
struct Course: Identifiable {
    let id = UUID()
    let name: String
    let room: String
    let color: Color
    var unfinishedTasks: Int
}

// 时间槽模型
struct TimeSlot: Identifiable {
    let id = UUID()
    let period: Int
    let dayOfWeek: Int
    var course: Course?
}

struct TimetableCourse {
    let name: String
    let room: String
    let teacher: String
    let startTime: String
    let endTime: String
    var colorIndex: Int = 1  // デフォルトカラーインデックス
} 