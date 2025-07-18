import Foundation

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

class APIService {
    static let shared = APIService()

    private init() {}

    // 通用的API请求方法
    func request<T>(
        endpoint: String,
        method: String = "POST",
        body: [String: Any],
        logTag: String,
        replacingPercentEncoding: Bool = true,
        decoder: @escaping (Data) -> Result<T, Error>
    ) -> (URLRequest) -> Void {
        return { [weak self] request in
            guard let self = self else { return }

            // リクエストデータをログに出力
            self.logRequest(endpoint: endpoint, body: body, logTag: logTag)

            var urlRequest = request

            // リクエストにCookieを追加
            urlRequest = CookieService.shared.addCookies(to: urlRequest)

            // APIリクエストの実行
            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                // エラー処理
                if let error = error {
                    print("【\(logTag)】エラー: \(error.localizedDescription)")
                    return
                }

                // HTTPレスポンス処理
                self.handleHTTPResponse(response: response, logTag: logTag)

                // データ確認
                guard let data = data else {
                    print("【\(logTag)】データなし")
                    return
                }

                // 生のレスポンスデータをログに出力
                self.logRawResponse(data: data, logTag: logTag)

                // レスポンスデータの処理
                guard
                    let decodedData = self.processResponseData(
                        data: data,
                        replacingPercentEncoding: replacingPercentEncoding,
                        logTag: logTag
                    )
                else { return }

                // デコードされたJSONデータをログに出力
                if let decodedString = String(data: decodedData, encoding: .utf8) {
                    print("【\(logTag)】デコード後レスポンス: \(decodedString)")
                }

                // カスタムデコーダーを使用してデータを処理
                let result = decoder(decodedData)
                switch result {
                case .success:
                    print("【\(logTag)】データ処理成功")
                case .failure(let error):
                    print("【\(logTag)】データ処理失敗: \(error.localizedDescription)")
                }
            }.resume()
        }
    }

    // 直接コールバックを返す新しいリクエストメソッド
    func request(
        request: URLRequest,
        logTag: String,
        replacingPercentEncoding: Bool = false,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        // リクエストデータをログに出力
        if let url = request.url?.absoluteString {
            print("【\(logTag)】リクエスト: \(url)")
        }

        if let httpBody = request.httpBody,
            let jsonStr = String(data: httpBody, encoding: .utf8)
        {
            print("【\(logTag)】リクエストボディ: \(jsonStr)")
        }

        var urlRequest = request

        // リクエストにCookieを追加
        urlRequest = CookieService.shared.addCookies(to: urlRequest)

        // APIリクエストの実行
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            // エラー処理
            if let error = error {
                print("【\(logTag)】エラー: \(error.localizedDescription)")
                completion(nil, response, error)
                return
            }

            // HTTPレスポンス処理
            self.handleHTTPResponse(response: response, logTag: logTag)

            // データ確認
            guard let data = data else {
                print("【\(logTag)】データなし")
                completion(
                    nil, response,
                    NSError(
                        domain: "APIService", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            // 生のレスポンスデータをログに出力
            self.logRawResponse(data: data, logTag: logTag)

            if replacingPercentEncoding {
                // レスポンスデータの処理
                guard
                    let decodedData = self.processResponseData(
                        data: data,
                        replacingPercentEncoding: replacingPercentEncoding,
                        logTag: logTag
                    )
                else {
                    completion(
                        nil, response,
                        NSError(
                            domain: "APIService", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to process response data"]
                        ))
                    return
                }

                completion(decodedData, response, nil)
            } else {
                completion(data, response, nil)
            }
        }.resume()
    }

    // リクエストログ出力
    private func logRequest(endpoint: String, body: [String: Any], logTag: String) {
        print("【\(logTag)】リクエスト: \(endpoint)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: body),
            let jsonStr = String(data: jsonString, encoding: .utf8)
        {
            print("【\(logTag)】リクエストボディ: \(jsonStr)")
        }
    }

    // HTTPレスポンス処理
    private func handleHTTPResponse(response: URLResponse?, logTag: String) {
        if let httpResponse = response as? HTTPURLResponse {
            print("【\(logTag)】HTTPステータスコード: \(httpResponse.statusCode)")

            // 保存Cookie - 确保所有响应的Cookie都被保存
            if let response = response, let url = response.url {
                // 使用响应的实际URL而不是固定域名
                CookieService.shared.saveCookies(from: response, for: url.absoluteString)

                // 複数のSet-Cookieヘッダーを処理
                if let headerFields = httpResponse.allHeaderFields as? [String: String] {
                    let setCookieHeaders = headerFields.filter {
                        $0.key.lowercased() == "set-cookie"
                    }
                    if !setCookieHeaders.isEmpty {
                        print("【\(logTag)】複数のSet-Cookieヘッダーを検出: \(setCookieHeaders.count)個")
                        setCookieHeaders.forEach { header in
                            print("【\(logTag)】Set-Cookie: \(header.value)")
                        }
                    }
                }

                print("【\(logTag)】Cookieを保存しました")
            }
        }
    }

    // 生レスポンスログ出力
    private func logRawResponse(data: Data, logTag: String) {
        if let rawResponseString = String(data: data, encoding: .utf8) {
            print("【\(logTag)】生レスポンス: \(rawResponseString)")
        }
    }

    // レスポンスデータ処理
    private func processResponseData(data: Data, replacingPercentEncoding: Bool, logTag: String)
        -> Data?
    {
        // 文字列に変換
        guard let responseString = String(data: data, encoding: .utf8) else {
            print("【\(logTag)】デコード失敗: レスポンス文字列の変換エラー")
            return nil
        }

        // パーセントデコード
        guard let percentDecodedString = responseString.removingPercentEncoding else {
            print("【\(logTag)】デコード失敗: パーセントデコードエラー")
            return nil
        }

        // 必要に応じて追加処理
        let processedString =
            replacingPercentEncoding
            ? percentDecodedString
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "+", with: " ")
            : percentDecodedString

        // データに戻す
        guard let processedData = processedString.data(using: .utf8) else {
            print("【\(logTag)】デコード失敗: 処理後文字列のデータ変換エラー")
            return nil
        }

        return processedData
    }

    // URLリクエストを作成
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
}
