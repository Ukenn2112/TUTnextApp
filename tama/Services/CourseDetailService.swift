import Foundation

class CourseDetailService {
    static let shared = CourseDetailService()
    
    private init() {}
    
    // 課程詳細情報を取得する関数
    func fetchCourseDetail(course: CourseModel, completion: @escaping (Result<CourseDetailResponse, Error>) -> Void) {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else {
            print("【課程詳細】ユーザー認証情報なし")
            completion(.failure(CourseDetailError.userNotAuthenticated))
            return
        }
        
        // API リクエストの準備
        guard let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/getJugyoDetailInfo") else {
            print("【課程詳細】無効なエンドポイント")
            completion(.failure(CourseDetailError.invalidEndpoint))
            return
        }
        
        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "loginUserId": user.username,
            "langCd": "",
            "encryptedLoginPassword": encryptedPassword,
            "productCd": "ap",
            "plainLoginPassword": "",
            "subProductCd": "apa",
            "data": [
                "jugyoCd": course.jugyoCd ?? "",
                "nendo": course.academicYear ?? 0,
                "kaikoNendo": course.courseYear ?? 0,
                "gakkiNo": course.courseTerm ?? 0,
                "jugyoKbn": course.jugyoKbn ?? "",
                "kaikoYobi": course.weekday ?? 0,
                "jigenNo": course.period ?? 0
            ]
        ]
        
        // リクエストデータをログに出力
        print("【課程詳細】リクエスト: \(url.absoluteString)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonStr = String(data: jsonString, encoding: .utf8) {
            print("【課程詳細】リクエストボディ: \(jsonStr)")
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("【課程詳細】リクエスト作成失敗")
            completion(.failure(CourseDetailError.requestCreationFailed))
            return
        }
        
        // リクエストの設定
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // APIリクエストの実行
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("【課程詳細】エラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // HTTPレスポンスをログに出力
            if let httpResponse = response as? HTTPURLResponse {
                print("【課程詳細】HTTPステータスコード: \(httpResponse.statusCode)")
                
                // 保存Cookie
                if let url = response?.url {
                    CookieService.shared.saveCookies(from: response!, for: url.absoluteString)
                    print("【課程詳細】Cookieを保存しました")
                }
            }
            
            guard let data = data else {
                print("【課程詳細】データなし")
                completion(.failure(CourseDetailError.noDataReceived))
                return
            }
            
            // 生のレスポンスデータをログに出力
            if let rawResponseString = String(data: data, encoding: .utf8) {
                print("【課程詳細】生レスポンス: \(rawResponseString)")
            }
            
            // URLエンコードされたレスポンスをデコード
            guard let responseString = String(data: data, encoding: .utf8),
                  let decodedData = responseString.removingPercentEncoding?
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "+", with: " ")
                .data(using: .utf8) else {
                print("【課程詳細】デコード失敗")
                completion(.failure(CourseDetailError.decodingFailed))
                return
            }
            
            // デコードされたJSONデータをログに出力
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                print("【課程詳細】デコード後レスポンス: \(decodedString)")
            }
            
            // JSONデータの解析
            do {
                if let json = try JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
                   let statusDto = json["statusDto"] as? [String: Any],
                   let success = statusDto["success"] as? Bool {
                    
                    print("【課程詳細】ステータス: success=\(success)")
                    
                    if success {
                        if let data = json["data"] as? [String: Any] {
                            // レスポンスデータの解析
                            let courseDetail = self.parseCourseDetailResponse(data)
                            completion(.success(courseDetail))
                        } else {
                            print("【課程詳細】データ解析失敗")
                            completion(.failure(CourseDetailError.dataParsingFailed))
                        }
                    } else {
                        if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                            let errorMessage = messageList.first ?? "Unknown error"
                            print("【課程詳細】APIエラー: \(errorMessage)")
                            completion(.failure(CourseDetailError.apiError(errorMessage)))
                        } else {
                            print("【課程詳細】不明なAPIエラー")
                            completion(.failure(CourseDetailError.apiError("Unknown error")))
                        }
                    }
                } else {
                    print("【課程詳細】レスポンス解析失敗")
                    completion(.failure(CourseDetailError.invalidResponse))
                }
            } catch {
                print("【課程詳細】JSON解析エラー: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // レスポンスデータを解析する関数
    private func parseCourseDetailResponse(_ data: [String: Any]) -> CourseDetailResponse {
        // 掲示情報の解析
        var announcements: [AnnouncementModel] = []
        if let keijiInfoDtoList = data["keijiInfoDtoList"] as? [[String: Any]] {
            for keijiInfo in keijiInfoDtoList {
                if let subject = keijiInfo["subject"] as? String,
                   let keijiAppendDate = keijiInfo["keijiAppendDate"] as? Int,
                   let keijiNo = keijiInfo["keijiNo"] as? Int {
                    let announcement = AnnouncementModel(
                        id: keijiNo,
                        title: subject,
                        date: keijiAppendDate
                    )
                    announcements.append(announcement)
                }
            }
        }
        
        // 出欠情報の解析
        var attendance = AttendanceModel(present: 0, absent: 0, late: 0, early: 0, sick: 0)
        if let attInfoDtoList = data["attInfoDtoList"] as? [[String: Any]],
           let attInfo = attInfoDtoList.first {
            attendance = AttendanceModel(
                present: attInfo["shusekiKaisu"] as? Int ?? 0,
                absent: attInfo["kessekiKaisu"] as? Int ?? 0,
                late: attInfo["chikokKaisu"] as? Int ?? 0,
                early: attInfo["sotaiKaisu"] as? Int ?? 0,
                sick: attInfo["koketsuKaisu"] as? Int ?? 0
            )
        }
        
        // 授業メモの取得
        let memo = data["jugyoMemo"] as? String ?? ""
        
        // シラバス公開フラグの取得
        let syllabusPubFlg = data["syllabusPubFlg"] as? Bool ?? false
        
        // 出欠管理フラグの取得
        let syuKetuKanriFlg = data["syuKetuKanriFlg"] as? Bool ?? false
        
        return CourseDetailResponse(
            announcements: announcements,
            attendance: attendance,
            memo: memo,
            syllabusPubFlg: syllabusPubFlg,
            syuKetuKanriFlg: syuKetuKanriFlg
        )
    }
    
    // メモを保存する関数
    func saveMemo(course: CourseModel, memo: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword else {
            print("【メモ保存】ユーザー認証情報なし")
            completion(.failure(CourseDetailError.userNotAuthenticated))
            return
        }
        
        // API リクエストの準備
        guard let url = URL(string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/setJugyoMemoInfo") else {
            print("【メモ保存】無効なエンドポイント")
            completion(.failure(CourseDetailError.invalidEndpoint))
            return
        }
        
        // リクエストボディの作成
        let requestBody: [String: Any] = [
            "loginUserId": user.username,
            "langCd": "",
            "encryptedLoginPassword": encryptedPassword,
            "productCd": "ap",
            "plainLoginPassword": "",
            "subProductCd": "apa",
            "data": [
                "jugyoCd": course.jugyoCd ?? "",
                "nendo": course.academicYear ?? 0,
                "jugyoMemo": memo
            ]
        ]
        
        // リクエストデータをログに出力
        print("【メモ保存】リクエスト: \(url.absoluteString)")
        if let jsonString = try? JSONSerialization.data(withJSONObject: requestBody),
           let jsonStr = String(data: jsonString, encoding: .utf8) {
            print("【メモ保存】リクエストボディ: \(jsonStr)")
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("【メモ保存】リクエスト作成失敗")
            completion(.failure(CourseDetailError.requestCreationFailed))
            return
        }
        
        // リクエストの設定
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // APIリクエストの実行
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("【メモ保存】エラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // HTTPレスポンスをログに出力
            if let httpResponse = response as? HTTPURLResponse {
                print("【メモ保存】HTTPステータスコード: \(httpResponse.statusCode)")
                
                // 保存Cookie
                if let url = response?.url {
                    CookieService.shared.saveCookies(from: response!, for: url.absoluteString)
                    print("【メモ保存】Cookieを保存しました")
                }
            }
            
            guard let data = data else {
                print("【メモ保存】データなし")
                completion(.failure(CourseDetailError.noDataReceived))
                return
            }
            
            // 生のレスポンスデータをログに出力
            if let rawResponseString = String(data: data, encoding: .utf8) {
                print("【メモ保存】生レスポンス: \(rawResponseString)")
            }
            
            // URLエンコードされたレスポンスをデコード
            guard let responseString = String(data: data, encoding: .utf8),
                  let decodedData = responseString.removingPercentEncoding?
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "+", with: " ")
                .data(using: .utf8) else {
                print("【メモ保存】デコード失敗")
                completion(.failure(CourseDetailError.decodingFailed))
                return
            }
            
            // デコードされたJSONデータをログに出力
            if let decodedString = String(data: decodedData, encoding: .utf8) {
                print("【メモ保存】デコード後レスポンス: \(decodedString)")
            }
            
            // JSONデータの解析
            do {
                if let json = try JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
                   let statusDto = json["statusDto"] as? [String: Any],
                   let success = statusDto["success"] as? Bool {
                    
                    print("【メモ保存】ステータス: success=\(success)")
                    
                    if success {
                        completion(.success(()))
                    } else {
                        if let messageList = statusDto["messageList"] as? [String], !messageList.isEmpty {
                            let errorMessage = messageList.first ?? "Unknown error"
                            print("【メモ保存】APIエラー: \(errorMessage)")
                            completion(.failure(CourseDetailError.apiError(errorMessage)))
                        } else {
                            print("【メモ保存】不明なAPIエラー")
                            completion(.failure(CourseDetailError.apiError("Unknown error")))
                        }
                    }
                } else {
                    print("【メモ保存】レスポンス解析失敗")
                    completion(.failure(CourseDetailError.invalidResponse))
                }
            } catch {
                print("【メモ保存】JSON解析エラー: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// エラー定義
enum CourseDetailError: Error {
    case userNotAuthenticated
    case invalidEndpoint
    case requestCreationFailed
    case noDataReceived
    case decodingFailed
    case dataParsingFailed
    case invalidResponse
    case apiError(String)
    
    var localizedDescription: String {
        switch self {
        case .userNotAuthenticated:
            return "ユーザー認証情報がありません"
        case .invalidEndpoint:
            return "無効なAPIエンドポイントです"
        case .requestCreationFailed:
            return "リクエストの作成に失敗しました"
        case .noDataReceived:
            return "データを受信できませんでした"
        case .decodingFailed:
            return "データのデコードに失敗しました"
        case .dataParsingFailed:
            return "データの解析に失敗しました"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .apiError(let message):
            return "APIエラー: \(message)"
        }
    }
} 
