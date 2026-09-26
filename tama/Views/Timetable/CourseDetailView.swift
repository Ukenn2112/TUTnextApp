import SwiftUI

struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var ratingService: RatingService
    @StateObject private var viewModel: CourseDetailViewModel

    let course: CourseModel
    let presetColors: [Color]
    @State var selectedColorIndex: Int
    let onColorChange: (Int) -> Void

    /// ページの中に直接置かれている場合の「閉じる」処理。
    /// シートとして出す場合は nil で、そのときだけシート用の表示（つまみ・detent・角丸）を付ける
    private let onInlineClose: (() -> Void)?

    @FocusState private var isMemoFocused: Bool
    @State private var safariDestination: SafariDestination?

    /// ページの中に直接置かれているかどうか
    private var isInline: Bool { onInlineClose != nil }

    init(
        course: CourseModel, presetColors: [Color], selectedColorIndex: Int,
        onColorChange: @escaping (Int) -> Void,
        onInlineClose: (() -> Void)? = nil
    ) {
        self.course = course
        self.presetColors = presetColors
        self._selectedColorIndex = State(initialValue: selectedColorIndex)
        self.onColorChange = onColorChange
        self.onInlineClose = onInlineClose
        self._viewModel = StateObject(wrappedValue: CourseDetailViewModel(course: course))
    }

    /// プレビュー用初期化
    fileprivate init(
        course: CourseModel, presetColors: [Color], selectedColorIndex: Int,
        onColorChange: @escaping (Int) -> Void,
        previewDetail: CourseDetailResponse
    ) {
        self.course = course
        self.presetColors = presetColors
        self._selectedColorIndex = State(initialValue: selectedColorIndex)
        self.onColorChange = onColorChange
        self.onInlineClose = nil
        self._viewModel = StateObject(wrappedValue: CourseDetailViewModel(course: course, previewDetail: previewDetail))
    }

    var body: some View {
        ZStack {
            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
                    .motionTransition(.fade)
            } else {
                detailScrollView
                    .motionTransition(.fade)
            }
        }
        .motionAnimation(Motion.standard, value: viewModel.errorMessage != nil)
        // ページの中に直接置くときは、地の色は右ペイン側（`TimetableDetailPane`）が塗る。
        // シートで出すときも他のページと同じ白い地にする
        .background(isInline ? Color.clear : CardSurface.pageFill)
        .modifier(SheetPresentationStyle(isEnabled: !isInline))
        .sheet(item: $safariDestination) { destination in
            if let notification = destination.dismissNotification {
                SafariWebView(url: destination.url, dismissNotification: notification)
            } else {
                SafariWebView(url: destination.url)
            }
        }
        .onAppear {
            viewModel.fetchCourseDetail()
            ratingService.recordSignificantEvent()
        }
        .onDisappear {
            if viewModel.isMemoChanged {
                viewModel.saveMemo()
                viewModel.isMemoChanged = false
            }
        }
    }

    /// 科目詳細の本体。
    ///
    /// 見出し（科目名・教員・教室）は手元の `CourseModel` からすぐに描く。
    /// 取得を待つ掲示・出欠・メモのカードは、読み込みが少し長引いたときだけ仮のデータをスケルトンで出し、
    /// 届いたら `Motion.standard` で本物に入れ替える（入れ替えの速さは ViewModel の `withMotion` が決める）
    private var detailScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroHeaderSection

                DelayedSkeletonGate(isLoading: viewModel.isLoading) { showsSkeleton in
                    let detail = showsSkeleton ? CourseDetailResponse.placeholder : viewModel.courseDetail
                    // スケルトンを出すまでの短い猶予のあいだは、空の状態（「掲示はありません」など）を
                    // 本物のように見せないよう、カードを隠しておく
                    let isHidden = viewModel.isLoading && !showsSkeleton
                    VStack(spacing: 16) {
                        announcementsCard(detail: detail)
                        attendanceCard(detail: detail)
                        memoCard
                    }
                    .skeleton(showsSkeleton)
                    .opacity(isHidden ? 0 : 1)
                    .allowsHitTesting(!isHidden)
                }

                linksCard
                colorPickerCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .readableWidth()
        }
        .simultaneousGesture(TapGesture().onEnded {
            isMemoFocused = false
        })
        // 引っ張って更新（表示中の内容は残したまま取り直す）
        .refreshable {
            await viewModel.refreshCourseDetail()
        }
    }

    /// 閉じる操作（シートなら閉じ、ページの中に直接置かれているなら呼び出し側へ返す）
    private func close() {
        if let onInlineClose {
            onInlineClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Safari遷移先

    private enum SafariDestination: Identifiable {
        case syllabus(URL)
        case announcement(URL)

        var id: String {
            switch self {
            case .syllabus(let url): return "syllabus-\(url)"
            case .announcement(let url): return "announcement-\(url)"
            }
        }

        var url: URL {
            switch self {
            case .syllabus(let url), .announcement(let url): return url
            }
        }

        var dismissNotification: Notification.Name? {
            switch self {
            case .announcement: return .announcementSafariDismissed
            case .syllabus: return nil
            }
        }
    }

    // MARK: - ヘルパー

    /// 選んでいる色。番号がプリセットの範囲外（色の数が変わった・保存値が古い）でも落ちないようにする
    private var selectedColor: Color {
        if presetColors.indices.contains(selectedColorIndex) {
            return presetColors[selectedColorIndex]
        }
        return presetColors.first ?? Color.gray
    }

    /// 時限バッジのテキスト色
    private var periodBadgeTextColor: Color {
        if colorScheme == .dark {
            // ダークモード: 暗いバッジ背景に対して白テキストでコントラスト確保
            return Color.white.opacity(0.9)
        }
        // ライトモード: パステル色から彩度アップ・明度ダウンで視認性の高い派生色を生成
        let base = selectedColor
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(base).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        guard saturation > 0.05 else { return .secondary }
        return Color(UIColor(hue: hue, saturation: min(saturation + 0.4, 1.0), brightness: max(brightness - 0.35, 0.3), alpha: 1.0))
    }

    /// 時限バッジの背景色
    private var periodBadgeBackgroundColor: Color {
        let base = selectedColor
        if colorScheme == .dark {
            // ダークモード: カラーセットのダーク変種を使用（tertiarySystemFillをベースに重ねる）
            return base.opacity(0.85)
        }
        // ライトモード: 彩度を微調整した半透明バッジ背景
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(base).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        guard saturation > 0.05 else { return Color(UIColor.secondarySystemFill) }
        return Color(UIColor(hue: hue, saturation: min(saturation + 0.15, 1.0), brightness: brightness, alpha: 0.45))
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey, trailing: Text? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.secondary)
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            if let trailing {
                trailing
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    /// 閉じるボタンの読み上げ名
    private var closeLabel: String {
        NSLocalizedString("閉じる", comment: "科目詳細を閉じる")
    }

}

// MARK: - 各カード

// 型の本体が長くなりすぎないよう、画面を組み立てる各カードは拡張に分けてある
extension CourseDetailView {

    // MARK: - Hero Header

    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    HStack {
                        Text(course.periodInfo)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(periodBadgeTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.tint(selectedColor), in: .capsule)

                        Spacer()

                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(Text(closeLabel))
                    }
                }
            } else {
                HStack {
                    Text(course.periodInfo)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(periodBadgeTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            ZStack {
                                Capsule().fill(Color(UIColor.tertiarySystemFill))
                                Capsule().fill(periodBadgeBackgroundColor)
                            }
                        )

                    Spacer()

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text(closeLabel))
                }
            }

            Text(course.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary)

            HStack(spacing: 16) {
                Label(course.teacher, systemImage: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)

                Label("\(course.room) 教室", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 掲示情報

    private func announcementsCard(detail: CourseDetailResponse?) -> some View {
        let announcements = detail?.announcements ?? []
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "doc.text", title: "掲示情報",
                trailing: Text("\(announcements.count)件"))

            if !announcements.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(announcements.enumerated()), id: \.element.id) {
                        index, announcement in
                        Button(action: {
                            if let url = viewModel.createAnnouncementURL(
                                announcement: announcement)
                            {
                                safariDestination = .announcement(url)
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(announcement.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(.leading)
                                    Text(announcement.formattedDate)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                        }

                        if index < announcements.count - 1 {
                            Divider()
                        }
                    }
                }
            } else {
                Text("掲示はありません")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
        .cardSurface(fill: CardSurface.raisedFill, outlined: true)
    }

    // MARK: - 出欠情報

    private func attendanceCard(detail: CourseDetailResponse?) -> some View {
        let attendanceData = CourseDetailViewModel.attendanceData(for: detail)
        let totalAttendance = attendanceData.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "person.crop.circle.badge.checkmark", title: "出欠情報",
                trailing: Text("全\(totalAttendance)回"))

            if totalAttendance > 0 {
                HStack(spacing: 0) {
                    ForEach(attendanceData) { data in
                        VStack(spacing: 4) {
                            Text("\(data.count)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(data.color)

                            Text(data.type)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)

                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(attendanceData) { data in
                            if data.count > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(data.color.opacity(0.8))
                                    .frame(
                                        width: max(
                                            4,
                                            CGFloat(data.count)
                                                / CGFloat(totalAttendance)
                                                * geometry.size.width
                                                - 2
                                        )
                                    )
                            }
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                .background(
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                )

                HStack(spacing: 0) {
                    ForEach(attendanceData) { data in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(data.color)
                                .frame(width: 8, height: 8)
                            Text(
                                "\(data.type) \(data.percentage(total: totalAttendance))"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            } else {
                Text("出欠情報はありません")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
        .cardSurface(fill: CardSurface.raisedFill, outlined: true)
    }

    // MARK: - メモ

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.secondary)
                Text("メモ")
                    .font(.system(size: 16, weight: .medium))
                Spacer()

                if isMemoFocused || viewModel.isMemoChanged {
                    Button(action: {
                        viewModel.saveMemo()
                        viewModel.isMemoChanged = false
                        isMemoFocused = false
                    }) {
                        Text("保存")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.appPrimary))
                    }
                    .motionTransition(.fade)
                }
            }
            .motionAnimation(Motion.quick, value: isMemoFocused || viewModel.isMemoChanged)

            ZStack(alignment: .topLeading) {
                if viewModel.memo.isEmpty && !isMemoFocused {
                    Text("持ち物や小テスト情報など\n授業に関することをメモできます。")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(UIColor.placeholderText))
                        .lineSpacing(4)
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.memo)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary)
                    .frame(minHeight: 60)
                    .focused($isMemoFocused)
                    .onChange(of: viewModel.memo) { _, newValue in
                        // 取得したメモが入っただけのときは「変更あり」にしない
                        viewModel.memoDidChange(to: newValue)
                    }
                    .onChange(of: isMemoFocused) { _, newValue in
                        if !newValue && viewModel.isMemoChanged {
                            viewModel.saveMemo()
                            viewModel.isMemoChanged = false
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .cardSurface(fill: CardSurface.raisedFill, outlined: true)
    }

    // MARK: - リンク

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "link", title: "リンク")

            Button(action: {
                if let url = viewModel.createSyllabusURL() {
                    safariDestination = .syllabus(url)
                }
            }) {
                HStack {
                    Image(systemName: "book.closed")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("シラバス")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .cardSurface(fill: CardSurface.raisedFill, outlined: true)
    }

    // MARK: - 色選択

    /// 色見本のカラム。
    /// 通常のiPhone（コンパクト幅）は従来どおり5等分、レギュラー幅では見本の間隔が広がりすぎないように列数を増やす
    private var colorColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 40, maximum: 72), spacing: 12)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    }

    private var colorPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "paintpalette", title: "色を選択")

            LazyVGrid(columns: colorColumns, spacing: 12) {
                // 0番（白）は見本に出さない（色が1つも無くても範囲が壊れないように indices から作る）
                ForEach(Array(presetColors.indices.dropFirst()), id: \.self) { index in
                    Button(action: {
                        withMotion(Motion.quick) {
                            selectedColorIndex = index
                        }
                        onColorChange(index)

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
                                            ? Color.primary.opacity(0.6)
                                            : Color.primary.opacity(0.1),
                                        lineWidth: selectedColorIndex == index ? 2.5 : 1
                                    )
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                    .opacity(selectedColorIndex == index ? 1 : 0)
                                    .scaleEffect(selectedColorIndex == index ? 1 : 0.5)
                                    // 跳ねずに素早く出す（選び直しは小さな状態の切り替え）
                                    .motionAnimation(Motion.quick, value: selectedColorIndex)
                            )
                    }
                }
            }
            .padding(.vertical, 4)
            .selectionHaptic(trigger: selectedColorIndex)
        }
        .cardSurface(fill: CardSurface.raisedFill, outlined: true)
    }

    // MARK: - エラー

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("エラーが発生しました")
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                viewModel.fetchCourseDetail()
            }) {
                Text("再読み込み")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.blue))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - シート用の表示

/// シートとして出すときだけ付ける表示（つまみ・detent・角丸）。
/// ページの中に直接置く場合はどれも当てはまらないので、まとめて外せるようにしてある
private struct SheetPresentationStyle: ViewModifier {

    let isEnabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            content
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
                .presentationCornerRadius(20)
        } else {
            content
        }
    }
}

#Preview {
    let sampleCourse = CourseModel(
        name: "データベースII(SQL)",
        room: "241",
        teacher: "齋藤 S.裕美",
        startTime: "1300",
        endTime: "1430",
        colorIndex: 6,
        weekday: 2,
        period: 3,
        jugyoCd: "DB001",
        academicYear: 2_025,
        courseYear: 2_025,
        courseTerm: 1,
        jugyoKbn: "A",
        keijiMidokCnt: 3
    )

    CourseDetailView(
        course: sampleCourse,
        presetColors: Color.coursePresets,
        selectedColorIndex: sampleCourse.colorIndex,
        onColorChange: { _ in },
        previewDetail: CourseDetailResponse.previewMock(for: sampleCourse)
    )
    .environmentObject(RatingService.shared)
}
