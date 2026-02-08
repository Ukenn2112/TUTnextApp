import Foundation

/// Legacy API service wrapper that uses Core/Networking modules
/// This maintains backward compatibility while migrating to Core modules
final class APIService {
    static let shared = APIService()
    
    private let networkClient: NetworkClientProtocol
    
    private init(networkClient: NetworkClientProtocol = NetworkClient.shared) {
        self.networkClient = networkClient
    }
    
    /// Create URL request
    func createRequest(url: URL, method: String = "POST", body: [String: Any]) -> URLRequest? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return request
    }
    
    /// Perform request with completion handler (legacy support)
    func request(
        request: URLRequest,
        logTag: String,
        replacingPercentEncoding: Bool = false,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        Task {
            do {
                let data = try await networkClient.requestRaw(.init(
                    path: request.url?.absoluteString ?? "",
                    method: HTTPMethod(rawValue: request.httpMethod ?? "POST"),
                    headers: request.allHTTPHeaderFields,
                    body: request.httpBody
                ))
                completion(data, nil, nil)
            } catch {
                completion(nil, nil, error)
            }
        }
    }
    
    /// Generic request with decoder
    func request<T>(
        endpoint: String,
        method: String = "POST",
        body: [String: Any],
        logTag: String,
        decoder: @escaping (Data) -> Result<T, Error>
    ) -> (URLRequest) -> Void {
        return { [weak self] request in
            guard let self = self else { return }
            
            Task {
                do {
                    let data = try await self.networkClient.requestRaw(.init(
                        path: endpoint,
                        method: HTTPMethod(rawValue: method),
                        body: try? JSONSerialization.data(withJSONObject: body)
                    ))
                    _ = decoder(data)
                } catch {
                    print("【\(logTag)】エラー: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - APIError

enum APIError: Error {
    case invalidURL
    case requestCreationFailed
    case noData
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .requestCreationFailed:
            return "リクエストの作成に失敗しました"
        case .noData:
            return "データがありません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .decodingError(let error):
            return "デコードエラー: \(error.localizedDescription)"
        }
    }
}
