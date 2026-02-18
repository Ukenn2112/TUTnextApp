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

    /// シングルトン ModelContainer（一度だけ作成し、全ターゲットで共有）
    static let shared: ModelContainer = {
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // スキーマ変更などで既存データと互換性がない場合、ストアを削除して再作成
            print("【SharedModelContainer】ModelContainer 作成失敗、ストアを再作成します: \(error)")
            try? FileManager.default.removeItem(at: storeURL)
            // WAL/SHM ファイルも削除
            let shmURL = storeURL.appendingPathExtension("shm")
            let walURL = storeURL.appendingPathExtension("wal")
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after store reset: \(error)")
            }
        }
    }()
}
