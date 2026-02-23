import SwiftUI

extension Color {
    // MARK: - Course Preset Colors
    /// 時間割のコースカード用プリセットカラー一覧（白を含む11色）
    /// Color.appPrimary は Assets.xcassets から Xcode が自動生成するため定義不要
    static let coursePresets: [Color] = [
        .white,
        Color.CoursePresets.coursePink,
        Color.CoursePresets.courseOrange,
        Color.CoursePresets.courseYellow,
        Color.CoursePresets.courseLightGreen,
        Color.CoursePresets.courseGreen,
        Color.CoursePresets.courseCyan,
        Color.CoursePresets.coursePinkPurple,
        Color.CoursePresets.coursePurple,
        Color.CoursePresets.courseBlue,
        Color.CoursePresets.courseMagenta,
    ]
}
