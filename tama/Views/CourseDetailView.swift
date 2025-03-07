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
    
    // シラバスシートの表示状態
    @State private var showingSyllabus = false
    @State private var showSafariView = false
    @State private var syllabusURL: URL?
    
    // 時限情報を計算
    private var periodInfo: String {
        return course.periodInfo
    }
    
    init(course: CourseModel, presetColors: [Color], selectedColorIndex: Int, onColorChange: @escaping (Int) -> Void, isLoggedIn: Binding<Bool>) {
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
              let jugyoCd = course.jugyoCd else {
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
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        print("【シラバスURL】jsonString: \(jsonString)")
        
        // カスタムエンコーディング
        let customEncoded = jsonString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "'", with: "%27")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: ",", with: "%2C")
            .replacingOccurrences(of: "/", with: "%2F")
            .replacingOccurrences(of: ":", with: "%3A")
            .replacingOccurrences(of: ";", with: "%3B")
            .replacingOccurrences(of: "=", with: "%3D")
            .replacingOccurrences(of: "?", with: "%3F")
            .replacingOccurrences(of: "{", with: "%7B")
            .replacingOccurrences(of: "}", with: "%7D")
        
        let encodedLoginInfo = customEncoded
            .replacingOccurrences(of: "%2522", with: "%22")
            .replacingOccurrences(of: "%255C", with: "%5C")
        
        print("【シラバスURL】encodedLoginInfo: \(encodedLoginInfo)")
        let urlString = "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encodedLoginInfo)"
        return URL(string: urlString)
    }
    
    // 添加一个计算属性来处理颜色的暗度调整
    private var adjustedHeaderColor: Color {
        let baseColor = presetColors[selectedColorIndex]
        return colorScheme == .dark ? 
            baseColor.opacity(0.8) : // 暗黑模式下降低不透明度
            baseColor
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
                    
                    Button("再ログイン") {
                        UserService.shared.clearCurrentUser()
                        dismiss()
                        isLoggedIn = false
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
                                    ForEach(viewModel.courseDetail?.announcements ?? []) { announcement in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    if !announcement.isRead {
                                                        Circle()
                                                            .fill(Color.red)
                                                            .frame(width: 8, height: 8)
                                                    }
                                                    Text(announcement.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                }
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
                                            
                                            GeometryReader { geometry in
                                                HStack(spacing: 0) {
                                                    // バーグラフ部分
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(data.color)
                                                        .frame(width: CGFloat(data.count) / CGFloat(viewModel.totalAttendance) * (geometry.size.width + 10) + 10)
                                                    
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
                        // VStack(alignment: .leading, spacing: 8) {
                        //     HStack {
                        //         Image(systemName: "note.text")
                        //             .foregroundColor(.gray)
                        //         Text("メモ")
                        //             .font(.system(size: 16, weight: .bold))
                        //     }
                        //     .padding(.vertical, 12)
                            
                        //     TextEditor(text: $viewModel.memo)
                        //         .font(.system(size: 14))
                        //         .foregroundColor(viewModel.memo.isEmpty ? .secondary : .primary)
                        //         .frame(minHeight: 40)
                        //         .overlay(
                        //             Group {
                        //                 if viewModel.memo.isEmpty {
                        //                     Text("持ち物や小テスト情報など\n授業に関することをメモできます。")
                        //                         .font(.system(size: 14))
                        //                         .foregroundColor(.gray)
                        //                         .lineSpacing(4)
                        //                         .frame(maxWidth: .infinity, alignment: .leading)
                        //                         .padding(.horizontal, 5)
                        //                         .padding(.top, 2)
                        //                         .allowsHitTesting(false)
                        //                 }
                        //             }
                        //         )
                        //         .padding(.bottom, 12)
                            
                        //     Divider()
                        // }
                        // .padding(.horizontal)
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
                                    SafariWebView(url: url)
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
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                ForEach(1..<presetColors.count, id: \.self) { index in
                                    Button(action: {
                                        selectedColorIndex = index
                                        onColorChange(index)
                                        
                                        // 授業コードがある場合は色を保存
                                        if let jugyoCd = course.jugyoCd {
                                            CourseColorService.shared.saveCourseColor(jugyoCd: jugyoCd, colorIndex: index)
                                        }
                                    }) {
                                        Circle()
                                            .fill(presetColors[index])
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColorIndex == index ? Color.black : Color.clear, lineWidth: 2)
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
        academicYear: 2025,
        courseYear: 2025,
        courseTerm: 1,
        jugyoKbn: "1",
        keijiMidokCnt: 1
    )
    
    let presetColors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),  // 浅粉色
        Color(red: 1.0, green: 0.9, blue: 0.8),  // 浅橙色
        Color(red: 1.0, green: 1.0, blue: 0.8),  // 浅黄色
        Color(red: 0.9, green: 1.0, blue: 0.8),  // 浅绿色
        Color(red: 0.8, green: 1.0, blue: 0.8),  // 绿色
        Color(red: 0.8, green: 1.0, blue: 1.0),  // 青色
        Color(red: 1.0, green: 0.8, blue: 0.9),  // 粉紫色
        Color(red: 0.9, green: 0.8, blue: 1.0),  // 浅紫色
        Color(red: 0.8, green: 0.9, blue: 1.0),  // 浅蓝色
        Color(red: 1.0, green: 0.9, blue: 1.0),  // 浅紫色
    ]
    
    CourseDetailView(
        course: sampleCourse,
        presetColors: presetColors,
        selectedColorIndex: 1,
        onColorChange: { _ in },
        isLoggedIn: .constant(true)
    )
} 
