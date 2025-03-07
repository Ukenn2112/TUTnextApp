import Foundation

class AssignmentService {
    static let shared = AssignmentService()
    private let apiService = APIService.shared
    
    private init() {}
    
    // 実際のAPIを使用する場合の実装
    func getAssignments(completion: @escaping (Result<[Assignment], Error>) -> Void) {
        // 実際のAPIエンドポイントに合わせて変更する必要があります
        let endpoint = "/api/assignments"
        let baseURL = "https://api.example.com" // 実際のAPIのベースURLに変更する
        
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "AssignmentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // APIリクエストの設定
        let body: [String: Any] = [:] // 必要に応じてリクエストボディを設定
        let logTag = "AssignmentAPI"
        
        // URLRequestの作成
        guard let request = apiService.createRequest(url: url, method: "GET", body: body) else {
            completion(.failure(NSError(domain: "AssignmentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        // APIリクエストの実行
        let requestHandler = apiService.request(
            endpoint: endpoint,
            method: "GET",
            body: body,
            logTag: logTag,
            decoder: { data in
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let response = try decoder.decode(AssignmentResponse.self, from: data)
                    return .success(response.assignments)
                } catch {
                    return .failure(error)
                }
            }
        )
        
        // リクエストの実行
        requestHandler(request)
    }
    
    // モックデータを返す関数（開発用）
    func getMockAssignments() -> [Assignment] {
        let calendar = Calendar.current
        let now = Date()
        
        // 今日の日付
        let today = calendar.startOfDay(for: now)
        
        // 明日の日付
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // 3日後の日付
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: today)!
        
        // 1週間後の日付
        let oneWeekLater = calendar.date(byAdding: .day, value: 7, to: today)!
        
        // 昨日の日付（期限切れ用）
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        return [
            Assignment(
                id: "1",
                title: "第3回レポート提出",
                courseId: "CS101",
                courseName: "プログラミング入門",
                dueDate: tomorrow,
                description: "第3章の内容に関するレポートを提出してください。",
                status: .pending,
                url: "https://example.com/assignments/1"
            ),
            Assignment(
                id: "2",
                title: "中間テスト準備",
                courseId: "MATH202",
                courseName: "応用数学",
                dueDate: threeDaysLater,
                description: "第1章から第5章までの内容について復習してください。",
                status: .pending,
                url: "https://example.com/assignments/2"
            ),
            Assignment(
                id: "3",
                title: "グループプロジェクト提出",
                courseId: "BUS303",
                courseName: "ビジネス戦略",
                dueDate: oneWeekLater,
                description: "グループで作成したビジネス戦略プランを提出してください。",
                status: .pending,
                url: "https://example.com/assignments/3"
            ),
            Assignment(
                id: "4",
                title: "期末レポート",
                courseId: "ENG101",
                courseName: "英語コミュニケーション",
                dueDate: yesterday,
                description: "授業で学んだ内容に関するレポートを提出してください。",
                status: .pending,
                url: "https://example.com/assignments/4"
            ),
            Assignment(
                id: "5",
                title: "小テスト",
                courseId: "HIST101",
                courseName: "世界史概論",
                dueDate: calendar.date(byAdding: .hour, value: 3, to: now)!,
                description: "第7章の内容に関する小テストを受けてください。",
                status: .pending,
                url: "https://example.com/assignments/5"
            )
        ]
    }
} 