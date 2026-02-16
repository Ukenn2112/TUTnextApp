import Combine
import SwiftUI

/// 授業詳細ViewModel
@MainActor
final class CourseDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var courseDetail: CourseDetailResponse?
    @Published var memo: String = ""
    @Published var isMemoChanged = false

    private var cancellables = Set<AnyCancellable>()
    private let course: CourseModel

    init(course: CourseModel) {
        self.course = course
        self.memo = ""
    }

    // 課程詳細情報を取得
    func fetchCourseDetail() {
        isLoading = true
        errorMessage = nil

        CourseDetailService.shared.fetchCourseDetail(course: course) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let detailResponse):
                    self.courseDetail = detailResponse
                    self.memo = detailResponse.memo
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("課程詳細の取得に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    // メモを保存
    func saveMemo() {
        isLoading = true
        errorMessage = nil

        CourseDetailService.shared.saveMemo(course: course, memo: memo) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    print("メモを保存しました")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("メモの保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    // 出欠データを取得
    var attendanceData: [AttendanceData] {
        guard let detail = courseDetail else {
            return [
                AttendanceData(type: NSLocalizedString("出席", comment: ""), count: 0, color: .green),
                AttendanceData(type: NSLocalizedString("欠席", comment: ""), count: 0, color: .red),
                AttendanceData(
                    type: NSLocalizedString("遅早", comment: ""), count: 0, color: .yellow)
            ]
        }

        return [
            AttendanceData(
                type: NSLocalizedString("出席", comment: ""), count: detail.attendance.present,
                color: .green),
            AttendanceData(
                type: NSLocalizedString("欠席", comment: ""), count: detail.attendance.absent,
                color: .red),
            AttendanceData(
                type: NSLocalizedString("遅早", comment: ""),
                count: detail.attendance.late + detail.attendance.early, color: .yellow)
        ]
    }

    // 掲示件数
    var announcementCount: Int {
        return courseDetail?.announcements.count ?? 0
    }

    // 合計出欠回数
    var totalAttendance: Int {
        return attendanceData.reduce(0) { $0 + $1.count }
    }
}

/// 出欠情報の表示用モデル
struct AttendanceData: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let color: Color

    // パーセンテージを計算するプロパティ
    func percentage(total: Int) -> String {
        guard total > 0 else { return "0%" }
        let value = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", value)  // 小数点以下を切り捨てて表示
    }
}
