import Foundation
import SwiftData

/// アプリとWidget間で共有するSwiftData ModelContainer
enum SharedModelContainer {

    /// 共有スキーマ
    static let schema = Schema([
        CachedTimetable.self,
        CachedBusSchedule.self,
        RoomChangeRecord.self,
        CourseColorRecord.self,
        PrintUploadRecord.self
    ])

    /// App Group コンテナURL
    private static let storeURL: URL = {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.meikenn.tama"
        )!
        return containerURL.appendingPathComponent("shared.store")
    }()

    /// 共有 ModelContainer を作成
    static func create() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
