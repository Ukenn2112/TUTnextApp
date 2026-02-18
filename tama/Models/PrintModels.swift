import Foundation

/// 印刷設定モデル
struct PrintSettings {
    var plex: PlexType
    var nUp: NUpType
    var startPage: Int
    var pin: String?

    init(plex: PlexType = .simplex, nUp: NUpType = .none, startPage: Int = 1, pin: String? = nil) {
        self.plex = plex
        self.nUp = nUp
        self.startPage = startPage
        self.pin = pin
    }
}

/// 両面印刷の種類
enum PlexType: String, CaseIterable, Identifiable {
    case simplex = "simplex"
    case duplex = "duplex"
    case tumble = "tumble"

    var id: String { self.rawValue }

    var apiValue: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .simplex: return NSLocalizedString("片面", comment: "")
        case .duplex: return NSLocalizedString("両面 (長辺とじ)", comment: "")
        case .tumble: return NSLocalizedString("両面 (短辺とじ)", comment: "")
        }
    }
}

/// まとめて1枚の種類
enum NUpType: String, CaseIterable, Identifiable {
    case none = "1"
    case two = "2"
    case four = "4"

    var id: String { self.rawValue }

    var apiValue: String {
        return self.rawValue
    }

    var displayName: String {
        switch self {
        case .none: return NSLocalizedString("しない", comment: "")
        case .two: return NSLocalizedString("2 アップ", comment: "")
        case .four: return NSLocalizedString("4 アップ", comment: "")
        }
    }
}

/// 印刷結果モデル
struct PrintResult: Codable {
    let printNumber: String
    let fileName: String
    let expiryDate: Date
    let pageCount: Int
    let duplex: String
    let fileSize: String
    let nUp: String

    /// 有効期限をローカライズされた文字列で表示する
    var formattedExpiryDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: expiryDate)
    }
}
