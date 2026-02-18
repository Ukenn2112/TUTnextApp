import Foundation
import SwiftData

// MARK: - Blob型キャッシュ（時刻表・バス時刻表）

/// 時刻表キャッシュ（JSON blob として保存）
@Model
final class CachedTimetable {
    @Attribute(.unique) var key: String = "timetable"
    var data: Data
    var lastFetchTime: Date

    init(data: Data, lastFetchTime: Date) {
        self.data = data
        self.lastFetchTime = lastFetchTime
    }
}

/// バス時刻表キャッシュ（JSON blob として保存）
@Model
final class CachedBusSchedule {
    @Attribute(.unique) var key: String = "busSchedule"
    var data: Data
    var lastFetchTime: Date

    init(data: Data, lastFetchTime: Date) {
        self.data = data
        self.lastFetchTime = lastFetchTime
    }
}

// MARK: - レコード型（個別エントリ）

/// 教室変更レコード
@Model
final class RoomChangeRecord {
    @Attribute(.unique) var courseName: String
    var newRoom: String
    var expiryDate: Date

    init(courseName: String, newRoom: String, expiryDate: Date) {
        self.courseName = courseName
        self.newRoom = newRoom
        self.expiryDate = expiryDate
    }
}

/// 科目カラーレコード
@Model
final class CourseColorRecord {
    @Attribute(.unique) var jugyoCd: String
    var colorIndex: Int

    init(jugyoCd: String, colorIndex: Int) {
        self.jugyoCd = jugyoCd
        self.colorIndex = colorIndex
    }
}

/// 印刷アップロード履歴レコード
@Model
final class PrintUploadRecord {
    var printNumber: String
    var fileName: String
    var expiryDate: Date
    var pageCount: Int
    var duplex: String
    var fileSize: String
    var nUp: String
    var createdAt: Date

    init(printNumber: String, fileName: String, expiryDate: Date,
         pageCount: Int, duplex: String, fileSize: String, nUp: String) {
        self.printNumber = printNumber
        self.fileName = fileName
        self.expiryDate = expiryDate
        self.pageCount = pageCount
        self.duplex = duplex
        self.fileSize = fileSize
        self.nUp = nUp
        self.createdAt = Date()
    }
}
