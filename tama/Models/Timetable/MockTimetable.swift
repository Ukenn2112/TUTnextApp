import Foundation
import SwiftUI

/// Timetable mock data for previews and testing
public enum MockTimetable {
    public static let sampleSemester = Semester(
        year: 2025,
        termNo: 1,
        termName: "春学期",
        isCurrent: true
    )
    
    public static let sampleCourses: [Course] = [
        Course(
            id: "course-001",
            name: "キャリア・デザインII C",
            room: "101",
            teacher: "葛本 幸枝",
            startTime: "0900",
            endTime: "1030",
            colorIndex: 1,
            weekday: .monday,
            period: 1,
            jugyoCd: "CD001",
            academicYear: 2025,
            courseYear: 2025,
            courseTerm: 1,
            jugyoKbn: "A",
            keijiMidokCnt: 1
        ),
        Course(
            id: "course-002",
            name: "コンピュータ・サイエンス",
            room: "242",
            teacher: "中村 有一",
            startTime: "1040",
            endTime: "1210",
            colorIndex: 2,
            weekday: .monday,
            period: 2,
            jugyoCd: "CS001",
            academicYear: 2025,
            courseYear: 2025,
            courseTerm: 1,
            jugyoKbn: "A",
            keijiMidokCnt: 1
        ),
        Course(
            id: "course-003",
            name: "中国ビジネスコミュニケーションII",
            room: "113",
            teacher: "田 園",
            startTime: "1440",
            endTime: "1610",
            colorIndex: 3,
            weekday: .monday,
            period: 4,
            jugyoCd: "CB001",
            academicYear: 2025,
            courseYear: 2025,
            courseTerm: 1,
            jugyoKbn: "A",
            keijiMidokCnt: 1
        ),
        Course(
            id: "course-004",
            name: "経営情報特講",
            room: "201",
            teacher: "青木 克彦",
            startTime: "0900",
            endTime: "1030",
            colorIndex: 4,
            weekday: .tuesday,
            period: 1,
            jugyoCd: "KJ001",
            academicYear: 2025,
            courseYear: 2025,
            courseTerm: 1,
            jugyoKbn: "A",
            keijiMidokCnt: 1
        ),
        Course(
            id: "course-005",
            name: "消費心理学",
            room: "211",
            teacher: "浜田 正幸",
            startTime: "1040",
            endTime: "1210",
            colorIndex: 5,
            weekday: .tuesday,
            period: 2,
            jugyoCd: "SK001",
            academicYear: 2025,
            courseYear: 2025,
            courseTerm: 1,
            jugyoKbn: "A",
            keijiMidokCnt: 1
        )
    ]
    
    public static let sampleTimetable = Timetable(
        id: "timetable-001",
        userId: "user-001",
        semester: sampleSemester,
        courses: sampleCourses
    )
    
    public static let sampleTimeSlots: [TimeSlot] = [
        TimeSlot(weekday: .monday, period: 1, startTime: "0900", endTime: "1030"),
        TimeSlot(weekday: .monday, period: 2, startTime: "1040", endTime: "1210"),
        TimeSlot(weekday: .monday, period: 3, startTime: "1210", endTime: "1340"),
        TimeSlot(weekday: .monday, period: 4, startTime: "1440", endTime: "1610")
    ]
    
    public static let sampleCourseDetail = CourseDetail(
        id: "detail-001",
        courseId: "course-001",
        announcements: [
            Announcement(id: 1, title: "休講通知", date: Date(), content: "来週の月曜日は休講です。"),
            Announcement(id: 2, title: "課題提出", date: Date().addingTimeInterval(-86400), content: "課題の提出期限は翌週です。")
        ],
        attendance: Attendance(present: 10, absent: 1, late: 2, early: 0, sick: 0),
        memo: "重要：期末テスト有",
        syllabusPublished: true,
        absenceManagement: true
    )
}
