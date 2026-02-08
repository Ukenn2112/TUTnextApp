//
//  TimetableViewModel.swift
//  TUTnext
//
//  MVVM Timetable ViewModel with async/await
//

import Foundation
import Combine

@MainActor
class TimetableViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var courses: [String: [String: CourseModel]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private let timetableService: TimetableService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(timetableService: TimetableService = .shared) {
        self.timetableService = timetableService
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        timetableService.$timetableData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timetableData in
                self?.courses = timetableData
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func fetchTimetableData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await timetableService.fetchTimetableData()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func updateCourseColor(day: String, period: String, colorIndex: Int) {
        guard let course = courses[day]?[period],
              let jugyoCd = course.jugyoCd else { return }
        
        CourseColorService.shared.saveCourseColor(jugyoCd: jugyoCd, colorIndex: colorIndex)
        
        // Update local state
        var updatedCourse = course
        updatedCourse.colorIndex = colorIndex
        courses[day]?[period] = updatedCourse
    }
    
    // MARK: - Data Accessors
    func getWeekdays() -> [String] {
        ["1", "2", "3", "4", "5"]
    }
    
    func getPeriods() -> [(String, String, String)] {
        let periods = [
            ("1", "08:50", "09:35"),
            ("2", "09:45", "10:30"),
            ("3", "10:40", "11:25"),
            ("4", "11:35", "12:20"),
            ("5", "13:10", "13:55"),
            ("6", "14:05", "14:50"),
            ("7", "15:00", "15:45"),
            ("8", "15:55", "16:40")
        ]
        return periods
    }
    
    func getCurrentWeekday() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let mapping: [Int: String] = [2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6"]
        return mapping[weekday] ?? "1"
    }
    
    func getCurrentPeriod() -> String {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute
        
        let periodTimes = [
            ("1", 530, 575),
            ("2", 585, 630),
            ("3", 640, 685),
            ("4", 695, 740),
            ("5", 790, 835),
            ("6", 845, 890),
            ("7", 900, 945),
            ("8", 955, 1000)
        ]
        
        for (period, start, end) in periodTimes {
            if currentMinutes >= start && currentMinutes < end {
                return period
            }
        }
        return "1"
    }
    
    // MARK: - Refresh
    func refresh() async {
        await fetchTimetableData()
    }
}
