import Foundation
import Combine

struct Teacher: Identifiable, Codable {
    var id = UUID() // 本地ID
    let name: String
    let furigana: String?
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case name, furigana, email
    }
}

// API响应模型
struct TeacherResponse: Codable {
    let status: Bool
    let data: [Teacher]
}

class TeacherEmailListService {
    // Use Core.Networking.APIService instead of deprecated typealias
    private let apiService = Core.Networking.APIService.shared
    
    func fetchTeachers() -> AnyPublisher<[Teacher], Error> {
        return Future<[Teacher], Error> { promise in
            guard let url = URL(string: "https://tama.qaq.tw/tmail") else {
                promise(.failure(URLError(.badURL)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            self.apiService.request(
                request: request,
                logTag: "教师邮件列表",
                replacingPercentEncoding: false
            ) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = data else {
                    promise(.failure(URLError(.badServerResponse)))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let teacherResponse = try decoder.decode(TeacherResponse.self, from: data)
                    
                    if teacherResponse.status {
                        promise(.success(teacherResponse.data))
                    } else {
                        promise(.failure(URLError(.badServerResponse)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
