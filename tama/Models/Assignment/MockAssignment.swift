import Foundation

/// Assignment mock data for previews and testing
public enum MockAssignment {
    public static let sampleAssignments: [Assignment] = [
        Assignment(
            id: "assign-001",
            title: "レポート課題第3回",
            courseId: "course-001",
            courseName: "コンピュータ・サイエンス",
            dueDate: Date().addingTimeInterval(86400 * 3),
            description: "期末レポートを提出してください。",
            status: .pending
        ),
        Assignment(
            id: "assign-002",
            title: "小テスト",
            courseId: "course-002",
            courseName: "データベースII",
            dueDate: Date().addingTimeInterval(86400),
            description: "Chapter 1-3の小テストです。",
            status: .pending
        ),
        Assignment(
            id: "assign-003",
            title: "プレゼンテーション",
            courseId: "course-003",
            courseName: "経営情報特講",
            dueDate: Date().addingTimeInterval(86400 * 7),
            description: "グループでのプレゼンテーション",
            status: .pending
        ),
        Assignment(
            id: "assign-004",
            title: "課題提出",
            courseId: "course-004",
            courseName: "消費心理学",
            dueDate: Date().addingTimeInterval(-3600),
            status: .overdue
        ),
        Assignment(
            id: "assign-005",
            title: "演習問題",
            courseId: "course-005",
            courseName: "世界の宗教",
            dueDate: Date().addingTimeInterval(86400 * 14),
            description: "テキスト演習問題1-5",
            status: .completed
        )
    ]
    
    public static let upcomingAssignments: [Assignment] = sampleAssignments
        .filter { !$0.isOverdue && $0.status != .completed }
        .sorted { $0.dueDate < $1.dueDate }
    
    public static let overdueAssignments: [Assignment] = sampleAssignments
        .filter { $0.isOverdue }
    
    public static let urgentAssignments: [Assignment] = sampleAssignments
        .filter { $0.isUrgent && !$0.isOverdue }
    
    public static let sampleSubmission = AssignmentSubmission(
        id: "submission-001",
        assignmentId: "assign-005",
        submittedAt: Date(),
        fileName: "report.pdf",
        fileURL: "https://example.com/uploads/report.pdf",
        notes: "遅れて申し訳ありません。"
    )
    
    public static let sampleSummary = AssignmentSummary.from(sampleAssignments)
}
