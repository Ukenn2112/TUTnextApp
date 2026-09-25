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
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )!
        return containerURL.appendingPathComponent("shared.store")
    }()

    /// 共有ストアの ModelConfiguration
    private static var configuration: ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
    }

    /// ModelContainer を作成する（ストアの削除などの副作用なし）
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [configuration])
    }

    /// シングルトン ModelContainer（アプリ本体用・一度だけ作成）
    /// 互換性がない場合はストアを再作成する。Widget 拡張からは使用しないこと。
    static let shared: ModelContainer = {
        do {
            return try makeContainer()
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
                return try makeContainer()
            } catch {
                fatalError("Failed to create ModelContainer after store reset: \(error)")
            }
        }
    }()

    /// Widget 拡張用の安全なアクセサ
    /// ストアの削除や fatalError を行わず、失敗時は nil を返す。
    /// 成功した場合のみキャッシュし、失敗時は次回アクセスで再試行する
    static var sharedForExtension: ModelContainer? {
        extensionLock.lock()
        defer { extensionLock.unlock() }
        if let cachedExtensionContainer { return cachedExtensionContainer }
        do {
            let container = try makeContainer()
            cachedExtensionContainer = container
            return container
        } catch {
            #if DEBUG
            print("【SharedModelContainer】拡張用 ModelContainer の作成に失敗しました: \(error)")
            #endif
            return nil
        }
    }

    /// 拡張用コンテナのキャッシュ（extensionLock で保護）
    nonisolated(unsafe) private static var cachedExtensionContainer: ModelContainer?
    private static let extensionLock = NSLock()
}
