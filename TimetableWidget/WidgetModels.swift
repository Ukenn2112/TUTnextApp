//
//  WidgetModels.swift
//  TimetableWidget
//
//  Shared models for widget extension
//

import Foundation
import SwiftUI

// MARK: - Weekday Enum

public enum Weekday: Int, Codable, CaseIterable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7
    
    public var displayName: String {
        switch self {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }
    
    public var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

// MARK: - Course Model

public struct Course: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var room: String
    public var teacher: String
    public var startTime: String
    public var endTime: String
    public var colorIndex: Int
    public var weekday: Weekday?
    public var period: Int?
    public var jugyoCd: String?
    public var academicYear: Int?
    public var courseYear: Int?
    public var courseTerm: Int?
    public var jugyoKbn: String?
    public var keijiMidokCnt: Int?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        room: String = "",
        teacher: String = "",
        startTime: String = "",
        endTime: String = "",
        colorIndex: Int = 1,
        weekday: Weekday? = nil,
        period: Int? = nil,
        jugyoCd: String? = nil,
        academicYear: Int? = nil,
        courseYear: Int? = nil,
        courseTerm: Int? = nil,
        jugyoKbn: String? = nil,
        keijiMidokCnt: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.teacher = teacher
        self.startTime = startTime
        self.endTime = endTime
        self.colorIndex = max(1, colorIndex)
        self.weekday = weekday
        self.period = period
        self.jugyoCd = jugyoCd
        self.academicYear = academicYear
        self.courseYear = courseYear
        self.courseTerm = courseTerm
        self.jugyoKbn = jugyoKbn
        self.keijiMidokCnt = keijiMidokCnt
    }
    
    public var periodInfo: String {
        if let weekday = weekday, let period = period {
            return "\(weekday.displayName)曜\(period)限"
        }
        return "\(weekday?.displayName ?? "") \(startTime) - \(endTime)"
    }
}

// MARK: - Color Extension for Course

extension Course {
    public var color: Color {
        let colors: [Color] = [
            .clear,
            Color(red: 1.0, green: 0.8, blue: 0.8),
            Color(red: 1.0, green: 0.9, blue: 0.8),
            Color(red: 1.0, green: 1.0, blue: 0.8),
            Color(red: 0.9, green: 1.0, blue: 0.8),
            Color(red: 0.8, green: 1.0, blue: 0.8),
            Color(red: 0.8, green: 1.0, blue: 1.0),
            Color(red: 1.0, green: 0.8, blue: 0.9),
            Color(red: 0.9, green: 0.8, blue: 1.0),
            Color(red: 0.8, green: 0.9, blue: 1.0),
            Color(red: 1.0, green: 0.9, blue: 1.0),
        ]
        
        guard colorIndex >= 0 && colorIndex < colors.count else {
            return colors[0]
        }
        return colors[colorIndex]
    }
}
