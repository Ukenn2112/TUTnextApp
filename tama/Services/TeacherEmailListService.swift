import Foundation
import Combine

/// 教員メール一覧取得サービス
final class TeacherEmailListService {
    private let apiService = APIService.shared

    /// 教員一覧を取得する
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
                logTag: "教員メール一覧",
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
