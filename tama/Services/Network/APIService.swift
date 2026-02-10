import Foundation

/// 共通APIリクエストサービス
final class APIService {
    static let shared = APIService()

    private init() {}

    // MARK: - パブリックメソッド

    /// デコーダー付きAPIリクエスト
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

            self.logRequest(endpoint: endpoint, body: body, logTag: logTag)

            var urlRequest = request
            urlRequest = CookieService.shared.addCookies(to: urlRequest)

            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    print("【\(logTag)】エラー: \(error.localizedDescription)")
                    return
                }

                self.handleHTTPResponse(response: response, logTag: logTag)

                guard let data = data else {
                    print("【\(logTag)】データなし")
                    return
                }

                self.logRawResponse(data: data, logTag: logTag)

                guard
                    let decodedData = self.processResponseData(
                        data: data,
                        replacingPercentEncoding: replacingPercentEncoding,
                        logTag: logTag
                    )
                else { return }

                if let decodedString = String(data: decodedData, encoding: .utf8) {
                    print("【\(logTag)】デコード後レスポンス: \(decodedString)")
                }

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

    /// コールバック付きAPIリクエスト
    func request(
        request: URLRequest,
        logTag: String,
        replacingPercentEncoding: Bool = false,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        if let url = request.url?.absoluteString {
            print("【\(logTag)】リクエスト: \(url)")
        }

        if let httpBody = request.httpBody,
            let jsonStr = String(data: httpBody, encoding: .utf8)
        {
            print("【\(logTag)】リクエストボディ: \(jsonStr)")
        }

        var urlRequest = request
        urlRequest = CookieService.shared.addCookies(to: urlRequest)

        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("【\(logTag)】エラー: \(error.localizedDescription)")
                completion(nil, response, error)
                return
            }

            self.handleHTTPResponse(response: response, logTag: logTag)

            guard let data = data else {
                print("【\(logTag)】データなし")
                completion(
                    nil, response,
                    NSError(
                        domain: "APIService", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            self.logRawResponse(data: data, logTag: logTag)

            if replacingPercentEncoding {
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

    /// URLRequestを作成する
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

    // MARK: - プライベートメソッド

    /// リクエストログ出力
    private func logRequest(endpoint: String, body: [String: Any], logTag: String) {
        print("【\(logTag)】リクエスト: \(endpoint)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: body),
            let jsonStr = String(data: jsonString, encoding: .utf8)
        {
            print("【\(logTag)】リクエストボディ: \(jsonStr)")
        }
    }

    /// HTTPレスポンス処理（Cookie保存含む）
    private func handleHTTPResponse(response: URLResponse?, logTag: String) {
        if let httpResponse = response as? HTTPURLResponse {
            print("【\(logTag)】HTTPステータスコード: \(httpResponse.statusCode)")

            // レスポンスの実際のURLを使用してCookieを保存
            if let response = response, let url = response.url {
                CookieService.shared.saveCookies(from: response, for: url.absoluteString)
                print("【\(logTag)】Cookieを保存しました")
            }
        }
    }

    /// 生レスポンスログ出力
    private func logRawResponse(data: Data, logTag: String) {
        if let rawResponseString = String(data: data, encoding: .utf8) {
            print("【\(logTag)】生レスポンス: \(rawResponseString)")
        }
    }

    /// レスポンスデータ処理（パーセントデコード等）
    private func processResponseData(data: Data, replacingPercentEncoding: Bool, logTag: String)
        -> Data?
    {
        guard let responseString = String(data: data, encoding: .utf8) else {
            print("【\(logTag)】デコード失敗: レスポンス文字列の変換エラー")
            return nil
        }

        guard let percentDecodedString = responseString.removingPercentEncoding else {
            print("【\(logTag)】デコード失敗: パーセントデコードエラー")
            return nil
        }

        let processedString =
            replacingPercentEncoding
            ? percentDecodedString
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "+", with: " ")
            : percentDecodedString

        guard let processedData = processedString.data(using: .utf8) else {
            print("【\(logTag)】デコード失敗: 処理後文字列のデータ変換エラー")
            return nil
        }

        return processedData
    }
}
