import Foundation
import SwiftUI

/// 印刷システムサービス
final class PrintSystemService {
    static let shared = PrintSystemService()

    private let fixedId = "836-tamauniv01"
    private let fixedPassword = "tama1989"
    private let baseURL = "https://cloudodp.fujifilm.com"

    private init() {}

    // ファイル拡張子からContent-Typeを取得
    private func getContentType(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "xdw":
            return "application/vnd.fujifilm.xdw"
        case "xbd":
            return "application/vnd.fujifilm.xbd"
        case "pdf":
            return "application/pdf"
        case "xps":
            return "application/vnd.ms-xpsdocument"
        case "oxps":
            return "application/oxps"
        case "jpg", "jpeg", "jpe":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "tif", "tiff":
            return "image/tiff"
        case "rtf":
            return "application/rtf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default:
            return "application/octet-stream"
        }
    }

    // 印刷システムにログインする
    func login(completion: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)/guestweb/login") else {
            completion(
                false,
                NSError(
                    domain: "PrintSystemService", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        // ログイン用のパラメータを設定
        let parameters = [
            "id": fixedId,
            "password": fixedPassword,
            "lang": "ja",
        ]

        // URLエンコードされたフォームデータを作成
        let postString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = postString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // リクエストを実行
        APIService.shared.request(request: request, logTag: "印刷システムログイン") { data, response, error in
            if let error = error {
                print("印刷システムログインエラー: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // HTTPレスポンスのステータスコードをチェック
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                completion(success, nil)
            } else {
                completion(
                    false,
                    NSError(
                        domain: "PrintSystemService", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }
        }
    }

    // ファイルをアップロードする
    func uploadFile(
        fileData: Data, fileName: String, settings: PrintSettings,
        completion: @escaping (PrintResult?, Error?) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/tenants/2102%3ACOD1/user/prints/") else {
            completion(
                nil,
                NSError(
                    domain: "PrintSystemService", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        // マルチパートフォームデータを作成するための境界文字列
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("token", forHTTPHeaderField: "X-CSRF-Token")

        // マルチパートフォームデータを構築
        var body = Data()

        // ファイルデータを追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: \(getContentType(for: fileName))\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // タイトル（ファイル名）を追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fileName)\r\n".data(using: .utf8)!)

        // isGlobalを追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"isGlobal\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)

        // colorModeを追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"colorMode\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto\r\n".data(using: .utf8)!)

        // plexを追加（片面/両面の設定）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"plex\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(settings.plex.apiValue)\r\n".data(using: .utf8)!)

        // nUpを追加（まとめて1枚の設定）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"nUp\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(settings.nUp.apiValue)\r\n".data(using: .utf8)!)

        // startPageを追加（開始ページの設定）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"startPage\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(settings.startPage)\r\n".data(using: .utf8)!)

        // PINコードが設定されている場合は追加
        if let pin = settings.pin, !pin.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"pin\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(pin)\r\n".data(using: .utf8)!)
        }

        // autoNetprintを追加
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"autoNetprint\"\r\n\r\n".data(using: .utf8)!)
        body.append("false\r\n".data(using: .utf8)!)

        // フォームデータの終了
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // リクエストを実行
        APIService.shared.request(request: request, logTag: "印刷ファイルアップロード") {
            data, response, error in
            if let error = error {
                print("印刷ファイルアップロードエラー: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(
                    nil,
                    NSError(
                        domain: "PrintSystemService", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            do {
                // JSONレスポンスをパース
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let id = json["id"] as? String
                {
                    // アップロード成功後、詳細情報を取得
                    self.fetchPrintDetails(id: id) { printResult, error in
                        if let error = error {
                            print("印刷詳細情報取得エラー: \(error.localizedDescription)")
                            completion(nil, error)
                            return
                        }
                        completion(printResult, nil)
                    }
                } else {
                    completion(
                        nil,
                        NSError(
                            domain: "PrintSystemService", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
                }
            } catch {
                print("JSONパースエラー: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }

    // 印刷詳細情報を取得する
    private func fetchPrintDetails(
        id: String, retryCount: Int = 0, completion: @escaping (PrintResult?, Error?) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/tenants/2102%3ACOD1/user/prints/\(id)") else {
            completion(
                nil,
                NSError(
                    domain: "PrintSystemService", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        APIService.shared.request(request: request, logTag: "印刷詳細情報取得") {
            [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("印刷詳細情報取得エラー: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(
                    nil,
                    NSError(
                        domain: "PrintSystemService", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // prCodeが空の場合、再試行
                    if let prCode = json["prCode"] as? String, !prCode.isEmpty {
                        // 日付フォーマッター
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

                        // 有効期限をUTCからローカル時間に変換
                        if let expiresAt = json["expiresAt"] as? String,
                            let utcDate = dateFormatter.date(from: expiresAt)
                        {
                            // ローカル時間用のフォーマッター
                            let localFormatter = DateFormatter()
                            localFormatter.dateStyle = .long
                            localFormatter.timeStyle = .short
                            localFormatter.timeZone = TimeZone.current

                            let formattedExpiryDate = localFormatter.string(from: utcDate)

                            // プリント結果を作成
                            let printResult = PrintResult(
                                printNumber: prCode,
                                fileName: json["title"] as? String ?? "",
                                expiryDate: formattedExpiryDate,
                                pageCount: json["pages"] as? Int ?? 0,
                                duplex: PlexType(rawValue: json["plex"] as? String ?? "")?
                                    .displayName ?? "片面",
                                fileSize: "\(json["size"] as? Int ?? 0) KB",
                                nUp: NUpType(rawValue: "\(json["nUp"] as? Int ?? 1)")?.displayName
                                    ?? "しない"
                            )
                            completion(printResult, nil)
                        } else {
                            completion(
                                nil,
                                NSError(
                                    domain: "PrintSystemService", code: 5,
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid date format"]))
                        }
                    } else {
                        // 50回まで再試行
                        if retryCount < 50 {
                            print("prCodeが空です。再試行します。（\(retryCount + 1)/50）")
                            // 1秒待ってから再試行
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.fetchPrintDetails(
                                    id: id, retryCount: retryCount + 1, completion: completion)
                            }
                        } else {
                            print("prCodeの取得に失敗しました。50回の再試行後も取得できませんでした。")
                            completion(
                                nil,
                                NSError(
                                    domain: "PrintSystemService", code: 4,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Failed to get prCode after 50 retries"
                                    ]))
                        }
                    }
                } else {
                    completion(
                        nil,
                        NSError(
                            domain: "PrintSystemService", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]))
                }
            } catch {
                print("JSONパースエラー: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
}
