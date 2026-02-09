import Foundation

// MARK: - NFC Error

enum NFCError: LocalizedError, Identifiable {
    case notAvailable
    case sessionInvalidated(reason: String)
    case tagConnectionFailed
    case unexpectedTagType
    case readFailed(serviceCode: String, blockIndex: Int)
    case dataDecodingFailed(description: String)
    case missingData(description: String)
    case systemBusy
    case sessionTimeout
    
    var id: String {
        errorDescription ?? "unknown"
    }
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFCリーダーはこのデバイスで利用できません。"
        case .sessionInvalidated(let reason):
            return "NFCセッションが無効になりました: \(reason)"
        case .tagConnectionFailed:
            return "カードへの接続に失敗しました。"
        case .unexpectedTagType:
            return "予期しないカードタイプです。FeliCaカードを使用してください。"
        case .readFailed(let serviceCode, let blockIndex):
            return "カードデータの読み取りに失敗しました (サービス: \(serviceCode), ブロック: \(blockIndex))。"
        case .dataDecodingFailed(let description):
            return "データのデコードに失敗しました: \(description)"
        case .missingData(let description):
            return "必要なデータが見つかりませんでした: \(description)"
        case .systemBusy:
            return "NFCシステムがビジー状態です。しばらくしてから再試行してください。"
        case .sessionTimeout:
            return "NFCセッションがタイムアウトしました。"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            return "デバイスのNFC設定を確認してください。"
        case .sessionInvalidated, .tagConnectionFailed:
            return "学生証をiPhoneの上部に再度近づけてください。"
        case .unexpectedTagType:
            return "FeliCa対応的学生証を使用してください。"
        case .readFailed, .dataDecodingFailed, .missingData:
            return "カードを再度読み取ってください。"
        case .systemBusy:
            return "少し待ってから再度お試しください。"
        case .sessionTimeout:
            return "時間を置いて再度お試しください。"
        }
    }
}

// MARK: - NFC Read Result

struct NFCReadResult {
    let studentID: String
    let userName: String
    let validityStart: String?
    let validityEnd: String?
}

// MARK: - NFC Reader Protocol

protocol NFCReaderProtocol: AnyObject {
    var studentID: String { get }
    var userName: String { get }
    var errorMessage: String? { get }
    var isScanning: Bool { get }
    
    func startSession()
    func invalidateSession()
}
