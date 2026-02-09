//
//  CourseDetailView.swift
//  TUTnext
//
//  Glassmorphism Course Detail View
//

import SwiftUI
import CoreStorage

struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CourseDetailViewModel
    let course: CourseModel
    let presetColors: [Color]
    @State var selectedColorIndex: Int
    let onColorChange: (Int) -> Void
    @Binding var isLoggedIn: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ratingService: RatingService
    
    @FocusState private var isMemoFocused: Bool
    @State private var showingSyllabus = false
    @State private var showSafariView = false
    @State private var syllabusURL: URL?
    @State private var isAnnouncementSafari = false
    
    private var adjustedHeaderColor: Color {
        let baseColor = presetColors[selectedColorIndex]
        return themeManager.colorScheme == .dark ? baseColor.opacity(0.8) : baseColor
    }
    
    init(
        course: CourseModel,
        presetColors: [Color],
        selectedColorIndex: Int,
        onColorChange: @escaping (Int) -> Void,
        isLoggedIn: Binding<Bool>
    ) {
        self.course = course
        self.presetColors = presetColors
        self._selectedColorIndex = State(initialValue: selectedColorIndex)
        self.onColorChange = onColorChange
        self._viewModel = StateObject(wrappedValue: CourseDetailViewModel(course: course))
        self._isLoggedIn = isLoggedIn
    }
    
    private var periodInfo: String {
        return course.periodInfo
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                if viewModel.isLoading {
                    LoadingView(message: "詳細を読み込み中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.fetchCourseDetail()
                    }
                } else {
                    contentView
                }
            }
        }
        .background(
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
        )
        .onAppear {
            viewModel.fetchCourseDetail()
            ratingService.recordSignificantEvent()
        }
        .sheet(isPresented: $showSafariView) {
            if let url = syllabusURL {
                if isAnnouncementSafari {
                    SafariWebView(url: url, dismissNotification: .announcementSafariDismissed)
                } else {
                    SafariWebView(url: url)
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                StyledText(periodInfo, style: .caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 10)
            
            StyledText(course.name, style: .titleLarge)
            
            StyledText("\(course.teacher)\n\(course.room)", style: .bodyMedium)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adjustedHeaderColor)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 24) {
            // Announcements Section
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)
                    StyledText("掲示情報", style: .titleSmall)
                    Spacer()
                    StyledText("\(viewModel.announcementCount)件", style: .caption)
                        .foregroundColor(.secondary)
                }
            } content: {
                if viewModel.announcementCount > 0 {
                    VStack(spacing: 8) {
                        ForEach(viewModel.courseDetail?.announcements ?? []) { announcement in
                            announcementRow(announcement)
                        }
                    }
                } else {
                    StyledText("掲示はありません", style: .bodySmall)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Attendance Section
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark.fill")
                        .foregroundColor(.accentColor)
                    StyledText("出欠情報", style: .titleSmall)
                    Spacer()
                    StyledText("全\(viewModel.totalAttendance)回", style: .caption)
                        .foregroundColor(.secondary)
                }
            } content: {
                if viewModel.totalAttendance > 0 {
                    attendanceChart
                } else {
                    StyledText("出欠情報はありません", style: .bodySmall)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Memo Section
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "note.text.fill")
                        .foregroundColor(.accentColor)
                    StyledText("メモ", style: .titleSmall)
                    Spacer()
                    if isMemoFocused || viewModel.isMemoChanged {
                        Button(action: {
                            viewModel.saveMemo()
                            viewModel.isMemoChanged = false
                            isMemoFocused = false
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            } content: {
                ZStack(alignment: .topLeading) {
                    if viewModel.memo.isEmpty {
                        Text("持ち物や小テスト情報など\n授業に関することをメモできます。")
                            .typography(.bodySmall)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .padding(.horizontal, 5)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $viewModel.memo)
                        .typography(.bodySmall)
                        .frame(minHeight: 80)
                        .focused($isMemoFocused)
                        .onChange(of: viewModel.memo) { _, _ in
                            viewModel.isMemoChanged = true
                        }
                        .onChange(of: isMemoFocused) { _, newValue in
                            if !newValue && viewModel.isMemoChanged {
                                viewModel.saveMemo()
                                viewModel.isMemoChanged = false
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.top, -5)
                }
            }
            
            // Links Section
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.accentColor)
                    StyledText("リンク", style: .titleSmall)
                }
            } content: {
                Button(action: {
                    if let url = createSyllabusURL() {
                        isAnnouncementSafari = false
                        showSafariView = true
                        syllabusURL = url
                    }
                }) {
                    HStack {
                        StyledText("シラバス", style: .bodyMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .foregroundColor(.primary)
            }
            
            // Color Selection Section
            GlassCardWithHeader {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.accentColor)
                    StyledText("色を選択", style: .titleSmall)
                }
            } content: {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                    spacing: 8
                ) {
                    ForEach(1..<presetColors.count, id: \.self) { index in
                        Button(action: {
                            selectedColorIndex = index
                            onColorChange(index)
                            if let jugyoCd = course.jugyoCd {
                                CoreStorage.CourseColorService.shared.saveCourseColor(jugyoCd: jugyoCd, colorIndex: index)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(presetColors[index])
                                    .frame(width: 40, height: 40)
                                
                                if selectedColorIndex == index {
                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Announcement Row
    private func announcementRow(_ announcement: Announcement) -> some View {
        Button(action: {
            if let url = createAnnouncementURL(announcementId: announcement.id) {
                isAnnouncementSafari = true
                showSafariView = true
                syllabusURL = url
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    StyledText(announcement.title, style: .bodySmall)
                        .multilineTextAlignment(.leading)
                    StyledText(announcement.formattedDate, style: .captionSmall)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Attendance Chart
    private var attendanceChart: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.attendanceData) { data in
                HStack(spacing: 12) {
                    StyledText(data.type, style: .bodySmall)
                        .frame(width: 40, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(data.color)
                                .frame(
                                    width: CGFloat(data.count) / CGFloat(viewModel.totalAttendance) * (geometry.size.width + 10) + 10
                                )
                            
                            StyledText("\(data.count)", style: .bodySmall)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            Spacer()
                        }
                    }
                    .frame(height: 20)
                    
                    StyledText(data.percentage(total: viewModel.totalAttendance), style: .bodySmall)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
    
    // MARK: - URL Helpers
    private func createSyllabusURL() -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword,
              let courseYear = course.courseYear,
              let jugyoCd = course.jugyoCd
        else { return nil }
        
        let webApiLoginInfo: [String: Any] = [
            "paramaterMap": ["nendo": courseYear, "jugyoCd": jugyoCd],
            "parameterMap": "",
            "autoLoginAuthCd": "",
            "userId": user.username,
            "formId": "Pkx52301",
            "password": "",
            "funcId": "Pkx523",
            "encryptedPassword": encryptedPassword,
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return nil }
        
        let encoded = jsonString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
        
        let urlString = "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encoded)"
        return URL(string: urlString)
    }
    
    private func createAnnouncementURL(announcementId: Int) -> URL? {
        guard let user = UserService.shared.getCurrentUser(),
              let encryptedPassword = user.encryptedPassword
        else { return nil }
        
        let webApiLoginInfo: [String: Any] = [
            "autoLoginAuthCd": "",
            "parameterMap": "",
            "paramaterMap": ["keijiNo": announcementId],
            "encryptedPassword": encryptedPassword,
            "formId": "Bsd50702",
            "userId": user.username,
            "funcId": "Bsd507",
            "password": "",
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: webApiLoginInfo),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return nil }
        
        let encoded = jsonString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
        
        let urlString = "https://next.tama.ac.jp/uprx/up/pk/pky501/Pky50101.xhtml?webApiLoginInfo=\(encoded)"
        return URL(string: urlString)
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
        .pink, .orange, .yellow, .mint, .green,
        .cyan, .pink.opacity(0.8), .purple, .blue, .purple.opacity(0.8),
    ]
    
    CourseDetailView(
        course: sampleCourse,
        presetColors: presetColors,
        selectedColorIndex: 1,
        onColorChange: { _ in },
        isLoggedIn: .constant(true)
    )
    .environmentObject(ThemeManager.shared)
}
