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
    
    // 剩余时间是否少于2小时
    var isUrgent: Bool {
        if isOverdue {
            return false // 已过期的不算紧急
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: now, to: dueDate)
        
        if let hours = components.hour {
            return hours < 2 // 剩余时间少于2小时
        }
        
        return false
    }
}

enum AssignmentStatus: String, Codable {
    case pending = "pending"
    case completed = "completed"
}

// APIからのレスポンス形式
struct AssignmentResponse: Codable {
    var status: Bool
    var data: [APIAssignment]?
}

// APIから返される課題データの形式
struct APIAssignment: Codable {
    var title: String
    var courseId: String
    var courseName: String
    var dueDate: String
    var dueTime: String
    var description: String
    var url: String
    
    // APIAssignmentからAssignmentへの変換
    func toAssignment() -> Assignment {
        // 日付と時間を結合してDateに変換
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateTimeString = "\(dueDate) \(dueTime)"
        let date = dateFormatter.date(from: dateTimeString) ?? Date()
        
        return Assignment(
            id: UUID().uuidString, // APIからIDが返されないため、UUIDを生成
            title: title,
            courseId: courseId,
            courseName: courseName,
            dueDate: date,
            description: description,
            status: .pending, // デフォルトはpending
            url: url
        )
    }
} 