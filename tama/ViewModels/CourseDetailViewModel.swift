import Foundation
import SwiftUI

/// 授業詳細ViewModel
@MainActor
final class CourseDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var courseDetail: CourseDetailResponse?
    @Published var memo: String = ""
    var isMemoChanged = false

    private let course: CourseModel
    private let isPreview: Bool

    init(course: CourseModel) {
        self.course = course
        self.isPreview = false
        self.memo = ""
    }

    /// プレビュー用初期化（APIを呼ばずにモックデータをセット）
    init(course: CourseModel, previewDetail: CourseDetailResponse) {
        self.course = course
        self.isPreview = true
        self.courseDetail = previewDetail
        self.memo = previewDetail.memo
        self.isLoading = false
    }

    // 課程詳細情報を取得
    func fetchCourseDetail() {
        guard !isPreview else { return }
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

    // MARK: - URL生成

    // シラバスURLを生成
    func createSyllabusURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword,
            let courseYear = course.courseYear,
            let jugyoCd = course.jugyoCd
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "paramaterMap": [
                "nendo": courseYear,
                "jugyoCd": jugyoCd
            ],
            "parameterMap": "",
            "autoLoginAuthCd": "",
            "userId": user.username,
            "formId": "Pkx52301",
            "password": "",
            "funcId": "Pkx523",
            "encryptedPassword": encryptedPassword
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        let encodedLoginInfo = jsonString.webAPIEncoded
        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }

    // 掲示URLを生成
    func createAnnouncementURL(announcementId: Int) -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "autoLoginAuthCd": "",
            "parameterMap": "",
            "paramaterMap": [
                "keijiNo": announcementId
            ],
            "encryptedPassword": encryptedPassword,
            "formId": "Bsd50702",
            "userId": user.username,
            "funcId": "Bsd507",
            "password": ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        let encodedLoginInfo = jsonString.webAPIEncoded
        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
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
