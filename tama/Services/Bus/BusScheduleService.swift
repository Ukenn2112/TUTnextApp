import Foundation

/// Bus schedule service protocol
public protocol BusScheduleServiceProtocol {
    func fetchBusSchedule() async throws -> BusSchedule
    func getCachedSchedule() -> BusSchedule?
    func isCacheValid() -> Bool
}

/// Bus schedule service implementation using Core modules
@MainActor
public final class BusScheduleService: BusScheduleServiceProtocol {
    public static let shared = BusScheduleService()
    
    private let repository: BusScheduleRepositoryProtocol
    private let storage: StorageProtocol
    private let cacheExpirationInterval: TimeInterval
    
    public init(
        repository: BusScheduleRepositoryProtocol = BusScheduleRepository(
            networkClient: NetworkClient.shared
        ),
        storage: StorageProtocol = Storage.shared,
        cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    ) {
        self.repository = repository
        self.storage = storage
        self.cacheExpirationInterval = cacheExpirationInterval
    }
    
    public func fetchBusSchedule() async throws -> BusSchedule {
        // Check cache validity first
        if let cached = getCachedSchedule(), isCacheValid() {
            return cached
        }
        
        // Fetch from repository
        let schedule = try await repository.fetchBusSchedule()
        
        // Cache the result
        try? storage.save(schedule, forKey: .busSchedule)
        try? storage.save(Date(), forKey: .busScheduleLastFetchTime)
        
        return schedule
    }
    
    public func getCachedSchedule() -> BusSchedule? {
        storage.retrieve(forKey: .busSchedule) as BusSchedule?
    }
    
    public func isCacheValid() -> Bool {
        guard let lastFetchTime: Date = storage.retrieve(forKey: .busScheduleLastFetchTime) else {
            return false
        }
        return Date().timeIntervalSince(lastFetchTime) < cacheExpirationInterval
    }
}

// MARK: - Bus Schedule Repository Protocol

public protocol BusScheduleRepositoryProtocol {
    func fetchBusSchedule() async throws -> BusSchedule
}

/// Bus schedule repository implementation
public final class BusScheduleRepository: BusScheduleRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    
    public init(networkClient: NetworkClientProtocol, baseURL: String = "https://tama.qaq.tw/bus") {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }
    
    public func fetchBusSchedule() async throws -> BusSchedule {
        guard let url = URL(string: "\(baseURL)/app_data") else {
            throw AppError.network(.noConnection)
        }
        
        // For bus schedule, we use direct URLRequest since it's a simple GET
        // This is adapted from the existing BusScheduleService
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(BusAPIResponse.self, from: data)
        
        return createBusSchedule(from: apiResponse)
    }
    
    private func createBusSchedule(from response: BusAPIResponse) -> BusSchedule {
        // Transform API response to domain model
        BusSchedule(
            weekdaySchedules: transformToDaySchedules(response.data.weekday, type: .weekday),
            saturdaySchedules: transformToDaySchedules(response.data.saturday, type: .saturday),
            wednesdaySchedules: transformToDaySchedules(response.data.wednesday, type: .wednesday),
            specialNotes: response.specialNotes,
            temporaryMessages: response.messages,
            pin: response.pin
        )
    }
    
    private func transformToDaySchedules(_ apiData: WeekdayScheduleData, type: BusSchedule.ScheduleType) -> [BusSchedule.DaySchedule] {
        var schedules: [BusSchedule.DaySchedule] = []
        
        if let fromSeiseki = apiData.fromSeisekiToSchool {
            schedules.append(BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: type,
                hourSchedules: transformHourSchedules(fromSeiseki)
            ))
        }
        
        if let fromNagayama = apiData.fromNagayamaToSchool {
            schedules.append(BusSchedule.DaySchedule(
                routeType: .fromNagayamaToSchool,
                scheduleType: type,
                hourSchedules: transformHourSchedules(fromNagayama)
            ))
        }
        
        if let toSeiseki = apiData.fromSchoolToSeiseki {
            schedules.append(BusSchedule.DaySchedule(
                routeType: .fromSchoolToSeiseki,
                scheduleType: type,
                hourSchedules: transformHourSchedules(toSeiseki)
            ))
        }
        
        if let toNagayama = apiData.fromSchoolToNagayama {
            schedules.append(BusSchedule.DaySchedule(
                routeType: .fromSchoolToNagayama,
                scheduleType: type,
                hourSchedules: transformHourSchedules(toNagayama)
            ))
        }
        
        return schedules
    }
    
    private func transformHourSchedules(_ apiSchedules: [BusSchedule.HourSchedule]) -> [BusSchedule.HourSchedule] {
        apiSchedules
    }
}

// MARK: - Supporting Types

private struct BusAPIResponse: Codable {
    let data: WeekdayScheduleData
    let messages: [String]?
    let pin: BusSchedule.PinData?
    let specialNotes: [BusSchedule.SpecialNote]
    
    enum CodingKeys: String, CodingKey {
        case data = "data"
        case messages
        case pin
        case specialNotes = "special_notes"
    }
}

private struct WeekdayScheduleData: Codable {
    let fromSeisekiToSchool: [BusSchedule.HourSchedule]?
    let fromNagayamaToSchool: [BusSchedule.HourSchedule]?
    let fromSchoolToSeiseki: [BusSchedule.HourSchedule]?
    let fromSchoolToNagayama: [BusSchedule.HourSchedule]?
    
    enum CodingKeys: String, CodingKey {
        case fromSeisekiToSchool = "from_seiseki_to_school"
        case fromNagayamaToSchool = "from_nagayama_to_school"
        case fromSchoolToSeiseki = "from_school_to_seiseki"
        case fromSchoolToNagayama = "from_school_to_nagayama"
    }
}
