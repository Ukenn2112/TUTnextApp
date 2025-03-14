import Foundation

class AssignmentService {
    static let shared = AssignmentService()
    private let apiService = APIService.shared
    private let userService = UserService.shared
    
    private init() {}
    
    // 実際のAPIを使用する場合の実装
    func getAssignments(completion: @escaping (Result<[Assignment], Error>) -> Void) {
        // APIエンドポイント
        let endpoint = "/kadai"
        let baseURL = "https://tama.qaq.tw" // 実際のAPIのベースURL
        
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "AssignmentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // ユーザー情報を取得
        guard let currentUser = userService.getCurrentUser(),
              let encryptedPassword = currentUser.encryptedPassword else {
            completion(.failure(NSError(domain: "AssignmentService", code: 1, userInfo: [NSLocalizedDescriptionKey: "ユーザー情報が見つかりません"])))
            return
        }
        
        // APIリクエストの設定
        let body: [String: Any] = [
            "username": currentUser.username,
            "encryptedPassword": encryptedPassword
        ]
        let logTag = "AssignmentAPI"
        
        // URLRequestの作成
        guard let request = apiService.createRequest(url: url, method: "POST", body: body) else {
            completion(.failure(NSError(domain: "AssignmentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        // APIリクエストの実行
        apiService.request(
            request: request,
            logTag: logTag
        ) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AssignmentService", code: 2, userInfo: [NSLocalizedDescriptionKey: "データが取得できませんでした"])))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(AssignmentResponse.self, from: data)
                
                if response.status, let apiAssignments = response.data {
                    // APIAssignmentをAssignmentに変換
                    let assignments = apiAssignments.map { $0.toAssignment() }
                    DispatchQueue.main.async {
                        completion(.success(assignments))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "AssignmentService", code: 3, userInfo: [NSLocalizedDescriptionKey: "APIエラー: データの取得に失敗しました"])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
} 