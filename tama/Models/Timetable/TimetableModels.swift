import Foundation

/// Academic semester model
public struct Semester: Codable, Identifiable, Equatable {
    public let id: String
    public let year: Int
    public let termNo: Int
    public let termName: String
    public var isCurrent: Bool
    
    public init(
        year: Int,
        termNo: Int,
        termName: String,
        isCurrent: Bool = false
    ) {
        self.id = "\(year)-\(termNo)"
        self.year = year
        self.termNo = termNo
        self.termName = termName
        self.isCurrent = isCurrent
    }
    
    public var shortYearString: String {
        String(year % 100)
    }
    
    public var fullDisplayName: String {
        "\(year)年度\(termName)"
    }
    
    public static let current = Semester(
        year: 2025,
        termNo: 1,
        termName: "春学期",
        isCurrent: true
    )
}

/// Weekday enumeration
public enum Weekday: Int, Codable, CaseIterable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    saturday = 6
    sunday = 7
    
    public var displayName: String {
        switch self {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }
}

/// Course model for timetable entries
public struct Course: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var room: String
    public var teacher: String
    public var startTime: String
    public var endTime: String
    public var colorIndex: Int
    public var weekday: Weekday?
    public var period: Int?
    public var jugyoCd: String?
    public var academicYear: Int?
    public var courseYear: Int?
    public var courseTerm: Int?
    public var jugyoKbn: String?
    public var keijiMidokCnt: Int?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        room: String = "",
        teacher: String = "",
        startTime: String = "",
        endTime: String = "",
        colorIndex: Int = 1,
        weekday: Weekday? = nil,
        period: Int? = nil,
        jugyoCd: String? = nil,
        academicYear: Int? = nil,
        courseYear: Int? = nil,
        courseTerm: Int? = nil,
        jugyoKbn: String? = nil,
        keijiMidokCnt: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.teacher = teacher
        self.startTime = startTime
        self.endTime = endTime
        self.colorIndex = max(1, colorIndex)
        self.weekday = weekday
        self.period = period
        self.jugyoCd = jugyoCd
        self.academicYear = academicYear
        self.courseYear = courseYear
        self.courseTerm = courseTerm
        self.jugyoKbn = jugyoKbn
        self.keijiMidokCnt = keijiMidokCnt
    }
    
    /// Formatted period information
    public var periodInfo: String {
        if let weekday = weekday, let period = period {
            return "\(weekday.displayName)曜\(period)限"
        }
        return "\(weekday?.displayName ?? "") \(startTime) - \(endTime)"
    }
}

/// Timetable model containing all courses for a semester
public struct Timetable: Codable, Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let semester: Semester
    public var courses: [Course]
    public var lastUpdated: Date?
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        semester: Semester,
        courses: [Course] = [],
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.semester = semester
        self.courses = courses
        self.lastUpdated = lastUpdated
    }
    
    /// Get courses for a specific weekday
    public func courses(for weekday: Weekday) -> [Course] {
        courses.filter { $0.weekday == weekday }
    }
    
    /// Get courses for a specific period
    public func courses(for weekday: Weekday, period: Int) -> [Course] {
        courses.filter { $0.weekday == weekday && $0.period == period }
    }
    
    /// Check if timetable is empty
    public var isEmpty: Bool {
        courses.isEmpty
    }
}

/// Time slot model
public struct TimeSlot: Codable, Identifiable, Equatable {
    public let id: String
    public let weekday: Weekday
    public let period: Int
    public var startTime: String
    public var endTime: String
    
    public init(
        id: String = UUID().uuidString,
        weekday: Weekday,
        period: Int,
        startTime: String = "",
        endTime: String = ""
    ) {
        self.id = id
        self.weekday = weekday
        self.period = period
        self.startTime = startTime
        self.endTime = endTime
    }
    
    /// Formatted display string
    public var displayName: String {
        "\(weekday.displayName)曜\(period)限"
    }
}

/// Course detail model containing additional course information
public struct CourseDetail: Codable, Identifiable, Equatable {
    public let id: String
    public let courseId: String
    public var announcements: [Announcement]
    public var attendance: Attendance
    public var memo: String
    public var syllabusPublished: Bool
    public var absenceManagement: Bool
    
    public init(
        id: String = UUID().uuidString,
        courseId: String,
        announcements: [Announcement] = [],
        attendance: Attendance = Attendance(),
        memo: String = "",
        syllabusPublished: Bool = false,
        absenceManagement: Bool = false
    ) {
        self.id = id
        self.courseId = courseId
        self.announcements = announcements
        self.attendance = attendance
        self.memo = memo
        self.syllabusPublished = syllabusPublished
        self.absenceManagement = absenceManagement
    }
}

/// Announcement model for course announcements
public struct Announcement: Codable, Identifiable, Equatable {
    public let id: Int
    public var title: String
    public var date: Date
    public var content: String?
    public var author: String?
    
    public init(id: Int, title: String, date: Date, content: String? = nil, author: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.content = content
        self.author = author
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

/// Attendance record for a course
public struct Attendance: Codable, Equatable {
    public var present: Int
    public var absent: Int
    public var late: Int
    public var early: Int
    public var sick: Int
    
    public init(
        present: Int = 0,
        absent: Int = 0,
        late: Int = 0,
        early: Int = 0,
        sick: Int = 0
    ) {
        self.present = present
        self.absent = absent
        self.late = late
        self.early = early
        self.sick = sick
    }
    
    public var total: Int {
        present + absent + late + early + sick
    }
    
    public var presentRate: Double {
        guard total > 0 else { return 0 }
        return Double(present) / Double(total) * 100
    }
}
