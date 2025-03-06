import SwiftUI
import Combine

class TimetableViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var courses: [String: [String: CourseModel]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var currentSemester: Semester = .current
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // サンプルデータを初期値として設定
        self.courses = CourseModel.sampleCourses
    }
    
    // MARK: - Public Methods
    
    /// 時間割データを取得
    func fetchTimetableData(forSemester semester: Semester? = nil) {
        isLoading = true
        errorMessage = nil
        
        let targetSemester = semester ?? currentSemester
        
        TimetableService.shared.fetchTimetableData(semester: targetSemester) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let timetableData):
                    if !timetableData.isEmpty {
                        self.courses = timetableData
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("時間割データの取得に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 課程の色を更新
    func updateCourseColor(day: String, period: String, colorIndex: Int) {
        if let course = courses[day]?[period] {
            // 課程モデルの色を更新
            courses[day]?[period]?.colorIndex = colorIndex
            
            // 授業コードがある場合は保存
            if let jugyoCd = course.jugyoCd {
                CourseColorService.shared.saveCourseColor(jugyoCd: jugyoCd, colorIndex: colorIndex)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 特定の時限が存在するかチェック
    func hasSpecificPeriod(_ period: String) -> Bool {
        let weekdays = getWeekdays()
        return weekdays.contains { day in
            courses[day]?.keys.contains(period) == true
        }
    }
    
    /// 曜日の配列を取得
    func getWeekdays() -> [String] {
        let baseWeekdays = ["月", "火", "水", "木", "金"]
        
        if let saturdayCourses = courses["土"], !saturdayCourses.isEmpty {
            return baseWeekdays + ["土"]
        }
        return baseWeekdays
    }
    
    /// 時限の配列を取得
    func getPeriods() -> [(String, String, String)] {
        let basePeriods = [
            ("1", "9:00", "10:30"),
            ("2", "10:40", "12:10"),
            ("3", "13:00", "14:30"),
            ("4", "14:40", "16:10"),
            ("5", "16:20", "17:50"),
            ("6", "18:00", "19:30"),
            ("7", "19:40", "21:10")
        ]
        
        // 時限の存在チェック
        let has7thPeriod = hasSpecificPeriod("7")
        let has6thPeriod = hasSpecificPeriod("6")
        
        if has7thPeriod {
            return basePeriods
        } else if has6thPeriod {
            return Array(basePeriods.prefix(6))
        } else {
            return Array(basePeriods.prefix(5))
        }
    }
    
    /// 現在の曜日を取得
    func getCurrentWeekday() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let japaneseWeekday = weekday == 1 ? 7 : weekday - 1
        
        let weekdays = getWeekdays()
        if (1...weekdays.count).contains(japaneseWeekday) {
            return weekdays[japaneseWeekday - 1]
        }
        return ""
    }
    
    /// 現在の時限を取得
    func getCurrentPeriod() -> String? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute  // 現在時刻を分単位で計算
        
        // 時限の時間範囲を定義
        let periodRanges: [(period: String, startMinutes: Int, endMinutes: Int)] = [
            ("1", 9 * 60, 10 * 60 + 30),      // 9:00-10:30
            ("2", 10 * 60 + 40, 12 * 60 + 10), // 10:40-12:10
            ("3", 13 * 60, 14 * 60 + 30),     // 13:00-14:30
            ("4", 14 * 60 + 40, 16 * 60 + 10), // 14:40-16:10
            ("5", 16 * 60 + 20, 17 * 60 + 50), // 16:20-17:50
            ("6", 18 * 60, 19 * 60 + 30),     // 18:00-19:30
            ("7", 19 * 60 + 40, 21 * 60 + 10)  // 19:40-21:10
        ]
        
        // 現在時刻が含まれる時限を探す
        for (period, start, end) in periodRanges {
            if currentTime >= start && currentTime <= end {
                return period
            }
        }
        
        return nil
    }
    
    /// 特定の曜日・時限の授業を取得
    func getCourse(for day: String, period: String) -> CourseModel? {
        return courses[day]?[period]
    }
    
    /// 全ての授業数を取得
    func getTotalCourseCount() -> Int {
        var count = 0
        for (_, periodCourses) in courses {
            count += periodCourses.count
        }
        return count
    }
} 