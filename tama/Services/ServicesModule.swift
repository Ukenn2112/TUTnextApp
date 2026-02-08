import Foundation

// MARK: - Services Module

/// TUTnext Services module providing access to all application services
public enum Services {
    // MARK: - Timetable Services
    
    public static var timetableService: TimetableServiceProtocol {
        TimetableService.shared
    }
    
    public static var courseDetailService: CourseDetailServiceProtocol {
        CourseDetailService.shared
    }
    
    // MARK: - Bus Services
    
    public static var busScheduleService: BusScheduleServiceProtocol {
        BusScheduleService.shared
    }
    
    // MARK: - Assignment Services
    
    public static var assignmentService: AssignmentServiceProtocol {
        AssignmentService.shared
    }
    
    // MARK: - Notification Services
    
    public static var notificationService: NotificationServiceProtocol {
        NotificationService.shared
    }
    
    // MARK: - Print Services
    
    public static var printSystemService: PrintSystemServiceProtocol {
        PrintSystemService.shared
    }
    
    // MARK: - OAuth Services
    
    public static var googleOAuthService: GoogleOAuthServiceProtocol {
        GoogleOAuthService.shared
    }
}

// MARK: - Service Initialization

extension Services {
    /// Initialize all services
    public static func initialize() {
        // Initialize services that require setup
        _ = NotificationService.shared
        _ = GoogleOAuthService.shared
    }
}
