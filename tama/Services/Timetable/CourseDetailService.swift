import Foundation

/// 授業詳細情報サービス
final class CourseDetailService {
    static let shared = CourseDetailService()

    private init() {}

    // 課程詳細情報を取得する関数
    func fetchCourseDetail(
        course: CourseModel, completion: @escaping (Result<CourseDetailResponse, Error>) -> Void
    ) {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            print("【課程詳細】ユーザー認証情報なし")
            completion(.failure(CourseDetailError.userNotAuthenticated))
            return
        }

        guard
            let url = URL(
                string:
                    "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/getJugyoDetailInfo")
        else {
            completion(.failure(CourseDetailError.invalidEndpoint))
            return
        }

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

        guard var request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(CourseDetailError.requestCreationFailed))
            return
        }
        request = HeaderService.shared.addCommonHeaders(to: request)
        request = HeaderService.shared.addAuthHeaders(to: request)

        APIService.shared.request(
            request: request,
            logTag: "課程詳細",
            replacingPercentEncoding: true
        ) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(CourseDetailError.noDataReceived))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool
                {
                    if success {
                        if let responseData = json["data"] as? [String: Any] {
                            completion(.success(self.parseCourseDetailResponse(responseData)))
                        } else {
                            completion(.failure(CourseDetailError.dataParsingFailed))
                        }
                    } else {
                        let errorMessage =
                            (statusDto["messageList"] as? [String])?.first ?? "Unknown error"
                        completion(.failure(CourseDetailError.apiError(errorMessage)))
                    }
                } else {
                    completion(.failure(CourseDetailError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // レスポンスデータを解析する関数
    private func parseCourseDetailResponse(_ data: [String: Any]) -> CourseDetailResponse {
        // 掲示情報の解析
        var announcements: [AnnouncementModel] = []
        if let keijiInfoDtoList = data["keijiInfoDtoList"] as? [[String: Any]] {
            for keijiInfo in keijiInfoDtoList {
                if let subject = keijiInfo["subject"] as? String,
                    let keijiAppendDate = keijiInfo["keijiAppendDate"] as? Int,
                    let keijiNo = keijiInfo["keijiNo"] as? Int
                {
                    let torkDate = keijiInfo["keijiTorkDate"] as? String
                    let announcement = AnnouncementModel(
                        id: keijiNo,
                        title: subject,
                        date: keijiAppendDate,
                        torkDate: torkDate
                    )
                    announcements.append(announcement)
                }
            }
        }

        // 出欠情報の解析
        var attendance = AttendanceModel(present: 0, absent: 0, late: 0, early: 0, sick: 0, unregistered: 0)
        if let attInfoDtoList = data["attInfoDtoList"] as? [[String: Any]],
            let attInfo = attInfoDtoList.first
        {
            attendance = AttendanceModel(
                present: attInfo["shusekiKaisu"] as? Int ?? 0,
                absent: attInfo["kessekiKaisu"] as? Int ?? 0,
                late: attInfo["chikokKaisu"] as? Int ?? 0,
                early: attInfo["sotaiKaisu"] as? Int ?? 0,
                sick: attInfo["koketsuKaisu"] as? Int ?? 0,
                unregistered: attInfo["mitourokuKaisu"] as? Int ?? 0
            )
        }

        let memo = data["jugyoMemo"] as? String ?? ""
        let syllabusPubFlg = data["syllabusPubFlg"] as? Bool ?? false
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
    func saveMemo(
        course: CourseModel, memo: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            completion(.failure(CourseDetailError.userNotAuthenticated))
            return
        }

        guard
            let url = URL(
                string: "https://next.tama.ac.jp/uprx/webapi/up/ap/Apa004Resource/setJugyoMemoInfo")
        else {
            completion(.failure(CourseDetailError.invalidEndpoint))
            return
        }

        let encodedMemo = memo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? memo

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
                "jugyoMemo": encodedMemo
            ]
        ]

        guard var request = APIService.shared.createRequest(url: url, body: requestBody) else {
            completion(.failure(CourseDetailError.requestCreationFailed))
            return
        }
        request = HeaderService.shared.addCommonHeaders(to: request)
        request = HeaderService.shared.addAuthHeaders(to: request)

        APIService.shared.request(
            request: request,
            logTag: "メモ保存",
            replacingPercentEncoding: true
        ) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(CourseDetailError.noDataReceived))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let statusDto = json["statusDto"] as? [String: Any],
                    let success = statusDto["success"] as? Bool
                {
                    if success {
                        completion(.success(()))
                    } else {
                        let errorMessage =
                            (statusDto["messageList"] as? [String])?.first ?? "Unknown error"
                        completion(.failure(CourseDetailError.apiError(errorMessage)))
                    }
                } else {
                    completion(.failure(CourseDetailError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
