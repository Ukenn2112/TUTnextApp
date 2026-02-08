//
//  CourseDetailViewModel.swift
//  TUTnext
//
//  MVVM Course Detail ViewModel with async/await
//

import Foundation
import Combine

@MainActor
class CourseDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var courseDetail: CourseDetailModel?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var memo: String = ""
    @Published var isMemoChanged = false
    
    // MARK: - Private Properties
    private let course: CourseModel
    private let courseDetailService: CourseDetailService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(course: CourseModel, courseDetailService: CourseDetailService = .shared) {
        self.course = course
        self.courseDetailService = courseDetailService
        loadMemo()
    }
    
    // MARK: - Public Methods
    func fetchCourseDetail() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detail = try await courseDetailService.fetchCourseDetail(for: course)
            self.courseDetail = detail
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func saveMemo() {
        guard let jugyoCd = course.jugyoCd else { return }
        
        if let error = CourseColorService.shared.saveMemo(jugyoCd: jugyoCd, memo: memo) {
            print("Failed to save memo: \(error)")
        } else {
            isMemoChanged = false
        }
    }
    
    private func loadMemo() {
        guard let jugyoCd = course.jugyoCd else { return }
        memo = CourseColorService.shared.getMemo(jugyoCd: jugyoCd) ?? ""
    }
    
    // MARK: - Computed Properties
    var announcementCount: Int {
        courseDetail?.announcements.count ?? 0
    }
    
    var totalAttendance: Int {
        courseDetail?.attendance.total ?? 0
    }
    
    var attendanceData: [AttendanceData] {
        guard let attendance = courseDetail?.attendance else { return [] }
        
        return [
            AttendanceData(type: "出席", count: attendance.present, color: .green),
            AttendanceData(type: "欠席", count: attendance.absent, color: .red),
            AttendanceData(type: "遅刻", count: attendance.late, color: .orange),
            AttendanceData(type: "早退", count: attendance.earlyLeave, color: .yellow)
        ].filter { $0.count > 0 }
    }
}

// MARK: - Attendance Data Model
struct AttendanceData: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let color: Color
    
    func percentage(total: Int) -> String {
        guard total > 0 else { return "0%" }
        let percent = Double(count) / Double(total) * 100
        return String(format: "%.1f%%", percent)
    }
}
