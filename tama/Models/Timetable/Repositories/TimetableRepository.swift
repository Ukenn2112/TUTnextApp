import Foundation

/// Timetable repository protocol defining data access operations
public protocol TimetableRepositoryProtocol {
    /// Fetch timetable for current user
    func fetchTimetable() async throws -> Timetable
    
    /// Fetch timetable for a specific semester
    func fetchTimetable(for semester: Semester) async throws -> Timetable
    
    /// Fetch course details
    func fetchCourseDetail(courseId: String) async throws -> CourseDetail
    
    /// Update course color
    func updateCourseColor(courseId: String, colorIndex: Int) async throws
    
    /// Save timetable locally
    func saveTimetable(_ timetable: Timetable) async throws
    
    /// Get all available semesters
    func fetchAvailableSemesters() async throws -> [Semester]
    
    /// Refresh timetable from server
    func refreshTimetable() async throws -> Timetable
}

/// Timetable repository implementation
public final class TimetableRepository: TimetableRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let storage: StorageProtocol
    private let userId: String
    
    public init(networkClient: NetworkClientProtocol, storage: StorageProtocol, userId: String) {
        self.networkClient = networkClient
        self.storage = storage
        self.userId = userId
    }
    
    public func fetchTimetable() async throws -> Timetable {
        // Try to get cached timetable first
        if let cachedTimetable = storage.retrieve(forKey: .timetable) as Timetable? {
            // Check if cache is still valid (less than 1 hour old)
            if let lastUpdated = cachedTimetable.lastUpdated,
               Date().timeIntervalSince(lastUpdated) < 3600 {
                return cachedTimetable
            }
        }
        
        // Fetch from server
        let timetable = try await fetchTimetableFromServer()
        
        // Cache the result
        try await saveTimetable(timetable)
        
        return timetable
    }
    
    public func fetchTimetable(for semester: Semester) async throws -> Timetable {
        let endpoint = APIEndpoint.timetable.fetch(semesterId: semester.id)
        
        let timetable: Timetable = try await networkClient.request(endpoint)
        
        return timetable
    }
    
    public func fetchCourseDetail(courseId: String) async throws -> CourseDetail {
        let endpoint = APIEndpoint.timetable.fetchCourseDetail(courseId: courseId)
        
        let response: CourseDetailResponse = try await networkClient.request(endpoint)
        
        return response.toCourseDetail()
    }
    
    public func updateCourseColor(courseId: String, colorIndex: Int) async throws {
        let endpoint = APIEndpoint.timetable.updateColor(courseId: courseId, colorIndex: colorIndex)
        
        _ = try await networkClient.request(endpoint)
        
        // Update cached timetable
        if var timetable = storage.retrieve(forKey: .timetable) as Timetable? {
            if let index = timetable.courses.firstIndex(where: { $0.id == courseId }) {
                timetable.courses[index].colorIndex = colorIndex
                try await saveTimetable(timetable)
            }
        }
    }
    
    public func saveTimetable(_ timetable: Timetable) async throws {
        var timetableToSave = timetable
        timetableToSave.lastUpdated = Date()
        storage.save(timetableToSave, forKey: .timetable)
    }
    
    public func fetchAvailableSemesters() async throws -> [Semester] {
        let endpoint = APIEndpoint.timetable.fetchSemesters
        
        let response: SemestersResponse = try await networkClient.request(endpoint)
        
        return response.semesters
    }
    
    public func refreshTimetable() async throws -> Timetable {
        let timetable = try await fetchTimetableFromServer()
        try await saveTimetable(timetable)
        return timetable
    }
    
    private func fetchTimetableFromServer() async throws -> Timetable {
        let endpoint = APIEndpoint.timetable.fetch(userId: userId)
        
        let response: TimetableResponse = try await networkClient.request(endpoint)
        
        return response.toTimetable(userId: userId)
    }
}

// MARK: - Supporting Types

private struct TimetableResponse: Codable {
    let data: TimetableData
    
    struct TimetableData: Codable {
        let semester: Semester
        let courses: [APICourse]
    }
    
    func toTimetable(userId: String) -> Timetable {
        Timetable(
            userId: userId,
            semester: data.semester,
            courses: data.courses.map { $0.toCourse() }
        )
    }
}

private struct APICourse: Codable {
    let id: String?
    let name: String
    let room: String?
    let teacher: String?
    let startTime: String?
    let endTime: String?
    let colorIndex: Int?
    let weekday: Int?
    let period: Int?
    let jugyoCd: String?
    
    func toCourse() -> Course {
        Course(
            id: id ?? UUID().uuidString,
            name: name,
            room: room ?? "",
            teacher: teacher ?? "",
            startTime: startTime ?? "",
            endTime: endTime ?? "",
            colorIndex: colorIndex ?? 1,
            weekday: weekday.flatMap { Weekday(rawValue: $0) },
            period: period,
            jugyoCd: jugyoCd
        )
    }
}

private struct CourseDetailResponse: Codable {
    let announcements: [APIAnnouncement]
    let attendance: APIAttendance
    let memo: String?
    let syllabusPubFlg: Bool?
    let syuKetuKanriFlg: Bool?
    
    func toCourseDetail() -> CourseDetail {
        CourseDetail(
            announcements: announcements.map { $0.toAnnouncement() },
            attendance: attendance.toAttendance(),
            memo: memo ?? "",
            syllabusPublished: syllabusPubFlg ?? false,
            absenceManagement: syuKetuKanriFlg ?? false
        )
    }
}

private struct APIAnnouncement: Codable {
    let id: Int
    let title: String
    let date: Int
    let content: String?
    let author: String?
    
    func toAnnouncement() -> Announcement {
        Announcement(
            id: id,
            title: title,
            date: Date(timeIntervalSince1970: TimeInterval(date / 1000)),
            content: content,
            author: author
        )
    }
}

private struct APIAttendance: Codable {
    let present: Int?
    let absent: Int?
    let late: Int?
    let early: Int?
    let sick: Int?
    
    func toAttendance() -> Attendance {
        Attendance(
            present: present ?? 0,
            absent: absent ?? 0,
            late: late ?? 0,
            early: early ?? 0,
            sick: sick ?? 0
        )
    }
}

private struct SemestersResponse: Codable {
    let semesters: [Semester]
}
