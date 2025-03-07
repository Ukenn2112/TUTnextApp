import Foundation

struct Assignment: Identifiable, Codable {
    var id: String
    var title: String
    var courseId: String
    var courseName: String
    var dueDate: Date
    var description: String
    var status: AssignmentStatus
    var url: String
    
    var remainingTimeText: String {
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
    
    var isOverdue: Bool {
        return Date() > dueDate
    }
    
    var isPending: Bool {
        return status == .pending
    }
}

enum AssignmentStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
}

struct AssignmentResponse: Codable {
    var assignments: [Assignment]
} 