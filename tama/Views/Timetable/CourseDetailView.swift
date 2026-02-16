import SwiftUI

struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CourseDetailViewModel
    let course: CourseModel
    let presetColors: [Color]
    @State var selectedColorIndex: Int
    let onColorChange: (Int) -> Void
    @Binding var isLoggedIn: Bool
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var ratingService: RatingService

    // メモの編集状態を管理するためのFocusState
    @FocusState private var isMemoFocused: Bool

    // シラバスシートの表示状態
    @State private var showingSyllabus = false
    @State private var showSafariView = false
    @State private var syllabusURL: URL?

    // 掲示リスト表示用の状態フラグ
    @State private var isAnnouncementSafari = false

    // 時限情報を計算
    private var periodInfo: String {
        return course.periodInfo
    }

    init(
        course: CourseModel, presetColors: [Color], selectedColorIndex: Int,
        onColorChange: @escaping (Int) -> Void, isLoggedIn: Binding<Bool>
    ) {
        self.course = course
        self.presetColors = presetColors
        self._selectedColorIndex = State(initialValue: selectedColorIndex)
        self.onColorChange = onColorChange
        self._viewModel = StateObject(wrappedValue: CourseDetailViewModel(course: course))
        self._isLoggedIn = isLoggedIn
    }

    // 最大出席回数（グラフの最大値）
    private var maxAttendance: Int {
        viewModel.attendanceData.map { $0.count }.max() ?? 1
    }

    // シラバスURLを生成する関数
    private func createSyllabusURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword,
            let courseYear = course.courseYear,
            let jugyoCd = course.jugyoCd
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "paramaterMap": [
                "nendo": courseYear,
                "jugyoCd": jugyoCd
            ],
            "parameterMap": "",
            "autoLoginAuthCd": "",
            "userId": user.username,
            "formId": "Pkx52301",
            "password": "",
            "funcId": "Pkx523",
            "encryptedPassword": encryptedPassword
        ]
        print("【シラバスURL】encryptedPassword: \(encryptedPassword)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }
        print("【シラバスURL】jsonString: \(jsonString)")

        let encodedLoginInfo = jsonString.webAPIEncoded

        print("【シラバスURL】encodedLoginInfo: \(encodedLoginInfo)")
        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }

    // 掲示URLを生成する関数
    private func createAnnouncementURL(announcementId: Int) -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
            let encryptedPassword = user.encryptedPassword
        else {
            return nil
        }

        let webApiLoginInfo: [String: Any] = [
            "autoLoginAuthCd": "",
            "parameterMap": "",
            "paramaterMap": [
                "keijiNo": announcementId
            ],
            "encryptedPassword": encryptedPassword,
            "formId": "Bsd50702",
            "userId": user.username,
            "funcId": "Bsd507",
            "password": ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        let encodedLoginInfo = jsonString.webAPIEncoded

        let urlString =
            "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }

    // ダークモードに応じたヘッダー色の調整
    private var adjustedHeaderColor: Color {
        let baseColor = presetColors[selectedColorIndex]
        return colorScheme == .dark
            ? baseColor.opacity(0.8)
            : baseColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(periodInfo)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 10)
                Text(course.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(course.teacher)\n\(course.room)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(adjustedHeaderColor)

            if viewModel.isLoading {
                ProgressView("読み込み中...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("エラーが発生しました")
                        .font(.headline)
                        .padding(.bottom, 8)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("再読み込み") {
                        viewModel.fetchCourseDetail()
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // 掲示情報
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.gray)
                                Text("掲示情報")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(viewModel.announcementCount)件")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 16)

                            // 掲示リスト
                            if viewModel.announcementCount > 0 {
                                VStack(spacing: 8) {
                                    ForEach(viewModel.courseDetail?.announcements ?? []) {
                                        announcement in
                                        Button(action: {
                                            if let url = createAnnouncementURL(
                                                announcementId: announcement.id) {
                                                // 掲示リスト用のフラグをtrueに設定
                                                isAnnouncementSafari = true
                                                showSafariView = true
                                                syllabusURL = url
                                            }
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(announcement.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .multilineTextAlignment(.leading)
                                                    Text(announcement.formattedDate)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(10)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            } else {
                                Text("掲示はありません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                            }

                            Divider()
                        }
                        .padding(.horizontal)

                        // 出欠情報
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundColor(.gray)
                                Text("出欠情報")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("全\(viewModel.totalAttendance)回")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 16)

                            // 出欠グラフ
                            if viewModel.totalAttendance > 0 {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.attendanceData) { data in
                                        HStack(spacing: 12) {
                                            Text(data.type)
                                                .font(.system(size: 14))
                                                .frame(width: 40, alignment: .leading)
                                                .minimumScaleFactor(0.5)
                                                .lineLimit(1)

                                            GeometryReader { geometry in
                                                HStack(spacing: 0) {
                                                    // バーグラフ部分
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(data.color)
                                                        .frame(
                                                            width: CGFloat(data.count)
                                                                / CGFloat(viewModel.totalAttendance)
                                                                * (geometry.size.width + 10) + 10)

                                                    // 回数表示
                                                    Text("\(data.count)")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.gray)
                                                        .padding(.leading, 8)

                                                    Spacer()
                                                }
                                            }
                                            .frame(height: 20)

                                            // パーセンテージ
                                            Text(data.percentage(total: viewModel.totalAttendance))
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .frame(width: 50, alignment: .trailing)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            } else {
                                Text("出欠情報はありません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            Divider()
                        }
                        .padding(.horizontal)

                        // メモセクション
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.gray)
                                Text("メモ")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()

                                // 編集中の場合は保存ボタンを表示
                                if isMemoFocused || viewModel.isMemoChanged {
                                    Button(action: {
                                        viewModel.saveMemo()
                                        viewModel.isMemoChanged = false
                                        // 保存後にフォーカスを外す
                                        isMemoFocused = false
                                    }) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 12)

                            ZStack(alignment: .topLeading) {
                                if viewModel.memo.isEmpty {
                                    Text("持ち物や小テスト情報など\n授業に関することをメモできます。")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 5)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: $viewModel.memo)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .frame(minHeight: 30)
                                    .focused($isMemoFocused)
                                    .onChange(of: viewModel.memo) { _, _ in
                                        viewModel.isMemoChanged = true
                                    }
                                    .onChange(of: isMemoFocused) { _, newValue in
                                        // フォーカスが外れた時、かつメモが変更されていた場合に保存
                                        if !newValue && viewModel.isMemoChanged {
                                            viewModel.saveMemo()
                                            viewModel.isMemoChanged = false
                                        }
                                    }
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .padding(.top, -5)
                            }
                            .padding(.bottom, 12)

                            Divider()
                        }
                        .padding(.horizontal)

                        // リンクセクション
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.gray)
                                Text("リンク")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.top, 16)

                            Button(action: {
                                if let url = createSyllabusURL() {
                                    // シラバス表示の場合はフラグをfalseに設定
                                    isAnnouncementSafari = false
                                    showSafariView = true
                                    syllabusURL = url
                                }
                            }) {
                                HStack {
                                    Text("シラバス")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.primary)
                            .sheet(isPresented: $showSafariView) {
                                if let url = syllabusURL {
                                    // 通知フラグの状態に基づいて通知を設定
                                    if isAnnouncementSafari {
                                        SafariWebView(
                                            url: url,
                                            dismissNotification: .announcementSafariDismissed)
                                    } else {
                                        SafariWebView(url: url)
                                    }
                                }
                            }

                            Divider()
                        }
                        .padding(.horizontal)

                        // 色選択セクション
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "paintpalette")
                                    .foregroundColor(.gray)
                                Text("色を選択")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.top, 16)

                            // 色選択グリッド
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 8), count: 5),
                                spacing: 8
                            ) {
                                ForEach(1..<presetColors.count, id: \.self) { index in
                                    Button(action: {
                                        selectedColorIndex = index
                                        onColorChange(index)

                                        // 授業コードがある場合は色を保存
                                        if let jugyoCd = course.jugyoCd {
                                            CourseColorService.shared.saveCourseColor(
                                                jugyoCd: jugyoCd, colorIndex: index)
                                        }
                                    }) {
                                        Circle()
                                            .fill(presetColors[index])
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        selectedColorIndex == index
                                                            ? Color.black : Color.clear,
                                                        lineWidth: 2)
                                            )
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.black)
                                                    .opacity(selectedColorIndex == index ? 1 : 0)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            viewModel.fetchCourseDetail()
            // 授業詳細表示の重要イベントを記録
            ratingService.recordSignificantEvent()
        }
    }
}

#Preview {
    let sampleCourse = CourseModel(
        name: "コンピュータ・サイエンス",
        room: "242",
        teacher: "中村 有一",
        startTime: "1040",
        endTime: "1210",
        colorIndex: 1,
        weekday: 1,
        period: 2,
        jugyoCd: "CS001",
        academicYear: 2_025,
        courseYear: 2_025,
        courseTerm: 1,
        jugyoKbn: "1",
        keijiMidokCnt: 1
    )

    let presetColors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),  // ライトピンク
        Color(red: 1.0, green: 0.9, blue: 0.8),  // ライトオレンジ
        Color(red: 1.0, green: 1.0, blue: 0.8),  // ライトイエロー
        Color(red: 0.9, green: 1.0, blue: 0.8),  // ライトグリーン
        Color(red: 0.8, green: 1.0, blue: 0.8),  // グリーン
        Color(red: 0.8, green: 1.0, blue: 1.0),  // シアン
        Color(red: 1.0, green: 0.8, blue: 0.9),  // ピンクパープル
        Color(red: 0.9, green: 0.8, blue: 1.0),  // ライトパープル
        Color(red: 0.8, green: 0.9, blue: 1.0),  // ライトブルー
        Color(red: 1.0, green: 0.9, blue: 1.0)  // ライトパープル
    ]

    CourseDetailView(
        course: sampleCourse,
        presetColors: presetColors,
        selectedColorIndex: 1,
        onColorChange: { _ in },
        isLoggedIn: .constant(true)
    )
}
