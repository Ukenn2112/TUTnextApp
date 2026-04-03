import Foundation

/// 当日の時間割を取得するサービス（/schedule/later エンドポイント経由）
final class TodayScheduleService {

    static let shared = TodayScheduleService()
    private init() {}

    // MARK: - キャッシュ（5分間有効）

    private var cachedData: TodayScheduleData?
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    /// キャッシュを強制的に無効化する（教室変更通知時等）
    func invalidateCache() {
        print("【Schedule】キャッシュ無効化")
        cachedData = nil
        cacheDate = nil
    }

    // MARK: - フェッチ

    /// 当日の時間割を取得する
    func fetchTodaySchedule() async throws -> TodayScheduleData {
        // キャッシュが有効ならそのまま返す
        if let cached = cachedData,
           let cacheTime = cacheDate,
           Date().timeIntervalSince(cacheTime) < cacheTTL {
            print("【Schedule】キャッシュヒット（残り\(String(format: "%.0f", cacheTTL - Date().timeIntervalSince(cacheTime)))秒）")
            return cached
        }

        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else {
            throw TodayScheduleError.userNotAuthenticated
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let todayString = dateFormatter.string(from: Date())

        guard let url = URL(string: "https://tama.qaq.tw/schedule/later") else {
            throw TodayScheduleError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "username": user.username,
            "encryptedPassword": encryptedPassword,
            "targetDate": todayString,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        if let httpResponse = urlResponse as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw TodayScheduleError.httpError(httpResponse.statusCode)
        }

        let response = try JSONDecoder().decode(TodayScheduleResponse.self, from: data)

        guard response.status, let scheduleData = response.data else {
            throw TodayScheduleError.apiError(response.message ?? "Unknown error")
        }

        // キャッシュ更新
        cachedData = scheduleData
        cacheDate = Date()

        print("【Schedule】取得成功: \(scheduleData.timeTable.count)件の授業")
        return scheduleData
    }
}

// MARK: - エラー

enum TodayScheduleError: LocalizedError {
    case userNotAuthenticated
    case invalidURL
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "ユーザーが認証されていません"
        case .invalidURL:
            return "無効なURLです"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .apiError(let message):
            return "APIエラー: \(message)"
        }
    }
}
