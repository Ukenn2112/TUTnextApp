import Foundation

/// Models Module - TUTNext App
///
/// This module contains all data models for the TUTNext application with:
/// - Full Codable support for JSON serialization/deserialization
/// - Validation property wrappers (@MinLength, @Email, @NonEmpty, etc.)
/// - Repository pattern for data access
/// - Mock data for previews and testing
/// - JSON fixtures for testing

// MARK: - Common Module

@_exported import Foundation

// MARK: - Common Models

public typealias ValidationError = Common.Validators.ValidationError
public typealias Validatable = Common.Validators.Validatable
public typealias MinLength = Common.Validators.MinLength
public typealias MaxLength = Common.Validators.MaxLength
public typealias Email = Common.Validators.Email
public typealias NonEmpty = Common.Validators.NonEmpty
public typealias Positive = Common.Validators.Positive
public typealias InRange = Common.Validators.InRange

// MARK: - User Models

public typealias User = User.Models.User
public typealias UserCredentials = User.Models.UserCredentials
public typealias UserProfileUpdate = User.Models.UserProfileUpdate
public typealias AuthToken = User.Models.AuthToken
public typealias UserSession = User.Models.UserSession
public typealias UserRepository = User.Repositories.UserRepository
public typealias UserRepositoryProtocol = User.Repositories.UserRepositoryProtocol

// MARK: - Timetable Models

public typealias Semester = Timetable.Models.Semester
public typealias Course = Timetable.Models.Course
public typealias Weekday = Timetable.Models.Weekday
public typealias Timetable = Timetable.Models.Timetable
public typealias TimetableItem = Timetable.Models.TimetableItem
public typealias TimeSlot = Timetable.Models.TimeSlot
public typealias CourseDetail = Timetable.Models.CourseDetail
public typealias Announcement = Timetable.Models.Announcement
public typealias Attendance = Timetable.Models.Attendance
public typealias TimetableRepository = Timetable.Repositories.TimetableRepository
public typealias TimetableRepositoryProtocol = Timetable.Repositories.TimetableRepositoryProtocol

// MARK: - Bus Models

public typealias BusRouteType = Bus.Models.BusRouteType
public typealias BusScheduleType = Bus.Models.BusScheduleType
public typealias BusTimeEntry = Bus.Models.BusTimeEntry
public typealias BusHourSchedule = Bus.Models.BusHourSchedule
public typealias BusDaySchedule = Bus.Models.BusDaySchedule
public typealias BusSpecialNote = Bus.Models.BusSpecialNote
public typealias BusTemporaryMessage = Bus.Models.BusTemporaryMessage
public typealias BusPinMessage = Bus.Models.BusPinMessage
public typealias BusSchedule = Bus.Models.BusSchedule
public typealias BusRoute = Bus.Models.BusRoute
public typealias BusStop = Bus.Models.BusStop
public typealias BusRepository = Bus.Repositories.BusRepository
public typealias BusRepositoryProtocol = Bus.Repositories.BusRepositoryProtocol

// MARK: - Assignment Models

public typealias AssignmentStatus = Assignment.Models.AssignmentStatus
public typealias Assignment = Assignment.Models.Assignment
public typealias AssignmentSubmission = Assignment.Models.AssignmentSubmission
public typealias AssignmentWithCourse = Assignment.Models.AssignmentWithCourse
public typealias AssignmentSummary = Assignment.Models.AssignmentSummary
public typealias AssignmentRepository = Assignment.Repositories.AssignmentRepository
public typealias AssignmentRepositoryProtocol = Assignment.Repositories.AssignmentRepositoryProtocol

// MARK: - Module Namespaces

public enum Common {
    public enum Validators {}
    public enum Transformers {}
    public enum Networking {}
}

public enum User {
    public enum Models {}
    public enum Mocks {}
    public enum Repositories {}
}

public enum Timetable {
    public enum Models {}
    public enum Mocks {}
    public enum Repositories {}
}

public enum Bus {
    public enum Models {}
    public enum Mocks {}
    public enum Repositories {}
}

public enum Assignment {
    public enum Models {}
    public enum Mocks {}
    public enum Repositories {}
}

// MARK: - Mock Data Access

public enum MockData {
    public enum User {}
    public enum Timetable {}
    public enum Bus {}
    public enum Assignment {}
}

// MARK: - JSON Fixtures Access

public enum JSONFixtures {
    public enum User {}
    public enum Timetable {}
    public enum Bus {}
    public enum Assignment {}
}
