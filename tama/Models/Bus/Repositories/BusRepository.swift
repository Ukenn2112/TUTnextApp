//
//  BusRepository
//  TUTnext
//
//  Data models for the application
//
import Foundation

/// Bus repository protocol defining data access operations
public protocol BusRepositoryProtocol {
    /// Fetch complete bus schedule
    func fetchBusSchedule() async throws -> BusSchedule
    
    /// Fetch schedule for a specific type (weekday, saturday, wednesday)
    func fetchSchedule(for type: BusScheduleType) async throws -> [BusDaySchedule]
    
    /// Get next bus times for a route
    func getNextBuses(
        routeType: BusRouteType,
        scheduleType: BusScheduleType,
        from origin: String?
    ) async throws -> [BusTimeEntry]
    
    /// Check for temporary messages
    func fetchTemporaryMessages() async throws -> [BusTemporaryMessage]
    
    /// Refresh schedule from server
    func refreshSchedule() async throws -> BusSchedule
}

/// Bus repository implementation
public final class BusRepository: BusRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let storage: StorageProtocol
    
    public init(networkClient: NetworkClientProtocol, storage: StorageProtocol) {
        self.networkClient = networkClient
        self.storage = storage
    }
    
    public func fetchBusSchedule() async throws -> BusSchedule {
        // Try cache first
        if let cachedSchedule = storage.retrieve(forKey: .busSchedule) as BusSchedule?,
           let lastUpdated = cachedSchedule.lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 3600 {
            return cachedSchedule
        }
        
        // Fetch from server
        let schedule = try await fetchBusScheduleFromServer()
        
        // Cache result
        storage.save(schedule, forKey: .busSchedule)
        
        return schedule
    }
    
    public func fetchSchedule(for type: BusScheduleType) async throws -> [BusDaySchedule] {
        let fullSchedule = try await fetchBusSchedule()
        return fullSchedule.schedules(for: type)
    }
    
    public func getNextBuses(
        routeType: BusRouteType,
        scheduleType: BusScheduleType,
        from origin: String? = nil
    ) async throws -> [BusTimeEntry] {
        let schedule = try await fetchSchedule(for: scheduleType)
        
        guard let daySchedule = schedule.first(where: { $0.routeType == routeType }) else {
            return []
        }
        
        // Get all times from now onwards
        let calendar = Calendar.current
        let now = Date()
        
        var nextTimes: [BusTimeEntry] = []
        
        for hourSchedule in daySchedule.hourSchedules {
            for timeEntry in hourSchedule.times {
                let entryDate = calendar.date(
                    bySettingHour: hourSchedule.hour,
                    minute: timeEntry.minute,
                    second: 0,
                    of: now
                ) ?? now
                
                if entryDate > now {
                    nextTimes.append(timeEntry)
                }
            }
        }
        
        return Array(nextTimes.prefix(5))
    }
    
    public func fetchTemporaryMessages() async throws -> [BusTemporaryMessage] {
        let schedule = try await fetchBusSchedule()
        return schedule.temporaryMessages ?? []
    }
    
    public func refreshSchedule() async throws -> BusSchedule {
        let schedule = try await fetchBusScheduleFromServer()
        
        var updatedSchedule = schedule
        updatedSchedule.lastUpdated = Date()
        
        storage.save(updatedSchedule, forKey: .busSchedule)
        
        return updatedSchedule
    }
    
    private func fetchBusScheduleFromServer() async throws -> BusSchedule {
        let endpoint = APIEndpoint.bus.fetchSchedule
        
        let response: BusAPIResponse = try await networkClient.request(endpoint)
        
        return response.toBusSchedule()
    }
}

// MARK: - API Response Models

private struct BusAPIResponse: Codable {
    let messages: [APIMessage]?
    let pin: APIPin?
    let data: BusData
    
    struct BusData: Codable {
        let weekday: ScheduleData
        let wednesday: ScheduleData
        let saturday: ScheduleData
        
        struct ScheduleData: Codable {
            let fromSeisekiToSchool: [APIHourSchedule]?
            let fromNagayamaToSchool: [APIHourSchedule]?
            let fromSchoolToSeiseki: [APIHourSchedule]?
            let fromSchoolToNagayama: [APIHourSchedule]?
        }
    }
    
    func toBusSchedule() -> BusSchedule {
        BusSchedule(
            weekdaySchedules: convertToDaySchedules(from: data.weekday, type: .weekday),
            saturdaySchedules: convertToDaySchedules(from: data.saturday, type: .saturday),
            wednesdaySchedules: convertToDaySchedules(from: data.wednesday, type: .wednesday),
            specialNotes: [],
            temporaryMessages: messages?.map { $0.toMessage() },
            pinMessage: pin?.toPinMessage()
        )
    }
    
    private func convertToDaySchedules(
        from data: BusData.ScheduleData,
        type: BusScheduleType
    ) -> [BusDaySchedule] {
        var schedules: [BusDaySchedule] = []
        
        if let fromSeiseki = data.fromSeisekiToSchool {
            schedules.append(BusDaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: type,
                hourSchedules: fromSeiseki.map { $0.toHourSchedule() }
            ))
        }
        
        if let fromNagayama = data.fromNagayamaToSchool {
            schedules.append(BusDaySchedule(
                routeType: .fromNagayamaToSchool,
                scheduleType: type,
                hourSchedules: fromNagayama.map { $0.toHourSchedule() }
            ))
        }
        
        if let toSeiseki = data.fromSchoolToSeiseki {
            schedules.append(BusDaySchedule(
                routeType: .fromSchoolToSeiseki,
                scheduleType: type,
                hourSchedules: toSeiseki.map { $0.toHourSchedule() }
            ))
        }
        
        if let toNagayama = data.fromSchoolToNagayama {
            schedules.append(BusDaySchedule(
                routeType: .fromSchoolToNagayama,
                scheduleType: type,
                hourSchedules: toNagayama.map { $0.toHourSchedule() }
            ))
        }
        
        return schedules
    }
}

private struct APIMessage: Codable {
    let title: String
    let url: String
    
    func toMessage() -> BusTemporaryMessage {
        BusTemporaryMessage(title: title, url: url)
    }
}

private struct APIPin: Codable {
    let title: String
    let url: String
    
    func toPinMessage() -> BusPinMessage {
        BusPinMessage(title: title, url: url)
    }
}

private struct APIHourSchedule: Codable {
    let hour: Int
    let times: [APITimeEntry]
    
    struct APITimeEntry: Codable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool?
        let specialNote: String?
    }
    
    func toHourSchedule() -> BusHourSchedule {
        BusHourSchedule(
            hour: hour,
            times: times.map { entry in
                BusTimeEntry(
                    hour: entry.hour,
                    minute: entry.minute,
                    isSpecial: entry.isSpecial ?? false,
                    specialNote: entry.specialNote
                )
            }
        )
    }
}
