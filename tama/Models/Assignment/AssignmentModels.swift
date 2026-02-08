import Foundation

/// Assignment submission status
public enum AssignmentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case overdue = "overdue"
    case submitted = "submitted"
    
    public var displayName: String {
        switch self {
        case .pending:
            return "未提出"
        case .completed:
            return "完了"
        case .overdue:
            return "期限切れ"
        case .submitted:
            return "提出済み"
        }
    }
    
    public var isPending: Bool {
        self == .pending
    }
}

/// Assignment model
public struct Assignment: Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var courseId: String
    public var courseName: String
    public var dueDate: Date
    public var description: String
    public var status: AssignmentStatus
    public var url: String
    public var createdAt: Date?
    public var updatedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        courseId: String,
        courseName: String,
        dueDate: Date,
        description: String = "",
        status: AssignmentStatus = .pending,
        url: String = "",
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.courseName = courseName
        self.dueDate = dueDate
        self.description = description
        self.status = status
        self.url = url
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Days remaining until due date
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dueDate)
        return max(0, components.day ?? 0)
    }
    
    /// Formatted remaining time string
    public var remainingTimeText: String {
        let calendar = Calendar.current
        let now = Date()
        
        if now > dueDate {
            return "期限切れ"
        }
        
        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: dueDate)
        
        if let days = components.day, days > 0 {
            return "\(days)日"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間"
        } else if let minutes = components.minute {
            return "\(minutes)分"
        }
        
        return "まもなく期限"
    }
    
    /// Check if assignment is overdue
    public var isOverdue: Bool {
        Date() > dueDate
    }
    
    /// Check if assignment is urgent (less than 2 hours remaining)
    public var isUrgent: Bool {
        guard !isOverdue else { return false }
        let hoursRemaining = dueDate.timeIntervalSince(Date()) / 3600
        return hoursRemaining < 2
    }
}

/// Assignment submission model
public struct AssignmentSubmission: Codable, Identifiable, Equatable {
    public let id: String
    public let assignmentId: String
    public var submittedAt: Date
    public var fileName: String?
    public var fileURL: String?
    public var notes: String?
    
    public init(
        id: String = UUID().uuidString,
        assignmentId: String,
        submittedAt: Date = Date(),
        fileName: String? = nil,
        fileURL: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.submittedAt = submittedAt
        self.fileName = fileName
        self.fileURL = fileURL
        self.notes = notes
    }
}

/// Summary of assignments
public struct AssignmentSummary: Codable {
    public var total: Int
    public var pending: Int
    public var completed: Int
    public var overdue: Int
    public var urgent: Int
    
    public init(
        total: Int = 0,
        pending: Int = 0,
        completed: Int = 0,
        overdue: Int = 0,
        urgent: Int = 0
    ) {
        self.total = total
        self.pending = pending
        self.completed = completed
        self.overdue = overdue
        self.urgent = urgent
    }
    
    /// Create summary from list of assignments
    public static func from(_ assignments: [Assignment]) -> AssignmentSummary {
        var summary = AssignmentSummary()
        summary.total = assignments.count
        
        for assignment in assignments {
            if assignment.isOverdue {
                summary.overdue += 1
            } else if assignment.isUrgent {
                summary.urgent += 1
            }
            
            switch assignment.status {
            case .pending:
                summary.pending += 1
            case .completed, .submitted:
                summary.completed += 1
            case .overdue:
                break
            }
        }
        
        return summary
    }
}
