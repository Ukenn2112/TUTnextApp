//
//  BusWidgetModels.swift
//  BusWidget
//
//  Shared models for bus widget extension
//

import Foundation
import SwiftUI

// MARK: - Bus Route Type

public enum BusRouteType: String, Codable, CaseIterable {
    case fromSeisekiToSchool = "fromSeisekiToSchool"
    case fromNagayamaToSchool = "fromNagayamaToSchool"
    case fromSchoolToSeiseki = "fromSchoolToSeiseki"
    case fromSchoolToNagayama = "fromSchoolToNagayama"
    
    public var displayName: String {
        switch self {
        case .fromSeisekiToSchool:
            return "聖蹟桜ヶ丘駅 → 大学"
        case .fromNagayamaToSchool:
            return "永山駅 → 大学"
        case .fromSchoolToSeiseki:
            return "大学 → 聖蹟桜ヶ丘駅"
        case .fromSchoolToNagayama:
            return "大学 → 永山駅"
        }
    }
}

// MARK: - Bus Schedule Type

public enum BusScheduleType: String, Codable, CaseIterable {
    case weekday
    case saturday
    case wednesday
    
    public var displayName: String {
        switch self {
        case .weekday: return "平日"
        case .saturday: return "土曜日"
        case .wednesday: return "水曜日"
        }
    }
}

// MARK: - Bus Time Entry

public struct BusTimeEntry: Codable, Identifiable, Equatable {
    public let id: String
    public let hour: Int
    public let minute: Int
    public let isSpecial: Bool
    public var specialNote: String?
    
    public init(
        id: String = UUID().uuidString,
        hour: Int,
        minute: Int,
        isSpecial: Bool = false,
        specialNote: String? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isSpecial = isSpecial
        self.specialNote = specialNote
    }
    
    public var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Hourly Bus Schedule

public struct BusHourSchedule: Codable, Identifiable, Equatable {
    public let id: String
    public let hour: Int
    public var times: [BusTimeEntry]
    
    public init(
        id: String = UUID().uuidString,
        hour: Int,
        times: [BusTimeEntry] = []
    ) {
        self.id = id
        self.hour = hour
        self.times = times
    }
}

// MARK: - Daily Bus Schedule

public struct BusDaySchedule: Codable, Identifiable, Equatable {
    public let id: String
    public let routeType: BusRouteType
    public let scheduleType: BusScheduleType
    public var hourSchedules: [BusHourSchedule]
    
    public init(
        id: String = UUID().uuidString,
        routeType: BusRouteType,
        scheduleType: BusScheduleType,
        hourSchedules: [BusHourSchedule] = []
    ) {
        self.id = id
        self.routeType = routeType
        self.scheduleType = scheduleType
        self.hourSchedules = hourSchedules
    }
    
    public var allTimes: [BusTimeEntry] {
        hourSchedules.flatMap { $0.times }
    }
}

// MARK: - Bus Special Note

public struct BusSpecialNote: Codable, Identifiable, Equatable {
    public let id: String
    public let symbol: String
    public let description: String
    
    public init(
        id: String = UUID().uuidString,
        symbol: String,
        description: String
    ) {
        self.id = id
        self.symbol = symbol
        self.description = description
    }
}

// MARK: - Bus Pin Message

public struct BusPinMessage: Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var url: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        url: String = ""
    ) {
        self.id = id
        self.title = title
        self.url = url
    }
}

// MARK: - Bus Schedule

public struct BusSchedule: Codable, Identifiable, Equatable {
    public let id: String
    public var weekdaySchedules: [BusDaySchedule]
    public var saturdaySchedules: [BusDaySchedule]
    public var wednesdaySchedules: [BusDaySchedule]
    public var specialNotes: [BusSpecialNote]
    public var temporaryMessages: [BusTemporaryMessage]?
    public var pinMessage: BusPinMessage?
    public var lastUpdated: Date?
    
    public init(
        id: String = UUID().uuidString,
        weekdaySchedules: [BusDaySchedule] = [],
        saturdaySchedules: [BusDaySchedule] = [],
        wednesdaySchedules: [BusDaySchedule] = [],
        specialNotes: [BusSpecialNote] = [],
        temporaryMessages: [BusTemporaryMessage]? = nil,
        pinMessage: BusPinMessage? = nil,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.weekdaySchedules = weekdaySchedules
        self.saturdaySchedules = saturdaySchedules
        self.wednesdaySchedules = wednesdaySchedules
        self.specialNotes = specialNotes
        self.temporaryMessages = temporaryMessages
        self.pinMessage = pinMessage
        self.lastUpdated = lastUpdated
    }
    
    public func schedules(for type: BusScheduleType) -> [BusDaySchedule] {
        switch type {
        case .weekday: return weekdaySchedules
        case .saturday: return saturdaySchedules
        case .wednesday: return wednesdaySchedules
        }
    }
}

// MARK: - Bus Temporary Message

public struct BusTemporaryMessage: Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var url: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        url: String = ""
    ) {
        self.id = id
        self.title = title
        self.url = url
    }
}
