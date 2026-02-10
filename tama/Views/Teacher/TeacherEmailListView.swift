import SwiftUI

// MARK: - メインビュー
struct TeacherEmailListView: View {
    @StateObject private var viewModel = TeacherEmailListViewModel()
    @State private var showingCopyConfirmation = false
    @State private var selectedSection: String? = nil
    @State private var showSearchBar = false
    @State private var visibleSection: String? = nil
    @State private var isManualSelection = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    // 五十音行
    private let japaneseSections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "その他"]
    
    // 表示用の五十音行（「その他」を「#」に置換）
    private let displaySections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "#"]
    
    // MARK: - ボディ
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                backgroundView
                
                VStack(spacing: 0) {
                    headerView
                    contentView
                }
            }
            .overlay(
                TeacherCopyConfirmationView(showing: showingCopyConfirmation)
            )
            .navigationBarHidden(true)
            .onAppear(perform: loadInitialData)
        }
    }
    
    // MARK: - 背景ビュー
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.3),
                colorScheme == .dark ? Color.black : Color.white
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 0) {
            if showSearchBar {
                searchBarView
            } else {
                titleBarView
            }
            
            if !viewModel.selectedTeachers.isEmpty {
                selectionBarView
            }
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .zIndex(1)
    }
    
    // MARK: - 検索バービュー
    private var searchBarView: some View {
        HStack {
            TeacherSearchBar(text: $viewModel.searchText) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSearchBar = false
                    viewModel.searchText = ""
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
    
    // MARK: - タイトルバービュー
    private var titleBarView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("教師連絡先")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("タップして選択して、メールアドレスをコピー")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                CircleActionButton(
                    iconName: "magnifyingglass",
                    colors: [.blue, .blue.opacity(0.8)],
                    action: { showSearchWithAnimation() }
                )
                
                CircleActionButton(
                    iconName: "xmark",
                    colors: [.gray, .gray.opacity(0.8)],
                    action: { presentationMode.wrappedValue.dismiss() }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - 選択バービュー
    private var selectionBarView: some View {
        TeacherSelectionBar(
            selectedCount: viewModel.selectedTeachers.count,
            onCopy: copySelectedEmails,
            onClear: clearSelectionWithAnimation
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95))
        ))
    }
    
    // MARK: - コンテンツビュー
    private var contentView: some View {
        ZStack {
            if viewModel.isLoading {
                TeacherLoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                TeacherErrorView(message: errorMessage, onRetry: viewModel.loadTeachers)
            } else if viewModel.filteredTeachers.isEmpty && !viewModel.searchText.isEmpty {
                TeacherEmptyResultView()
            } else {
                teacherListView
            }
        }
        .zIndex(0)
    }
    
    // MARK: - 教員一覧ビュー
    private var teacherListView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                teacherScrollView
                
                if shouldShowIndexView(width: geometry.size.width) {
                    indexNavigationView
                }
            }
        }
    }
    
    // MARK: - 教員スクロールビュー
    private var teacherScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(getSections(), id: \.self) { section in
                        if let teachers = getTeachersForSection(section), !teachers.isEmpty {
                            Section {
                                // 各グループに不可視のアンカーポイントを作成
                                Color.clear
                                    .frame(height: 1)
                                    .id("anchor_\(section)")
                                
                                TeacherSectionHeader(title: section)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                                    .background(
                                        // GeometryReaderで見出し位置を検出
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    updateVisibleSection(section: section, geometry: geometry)
                                                }
                                                .onChange(of: geometry.frame(in: .global).minY) { _, newY in
                                                    updateVisibleSection(section: section, geometry: geometry)
                                                }
                                        }
                                    )
                                
                                // 教員一覧
                                ForEach(teachers) { teacher in
                                    TeacherRow(
                                        teacher: teacher,
                                        isSelected: viewModel.isSelected(teacher: teacher),
                                        onToggle: { toggleTeacherSelection(teacher) },
                                        onCopy: { copyTeacherEmail(teacher) }
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }
            .onChange(of: selectedSection) { oldValue, newSection in
                scrollToSection(newSection, proxy: scrollProxy)
            }
        }
    }
    
    // MARK: - インデックスナビゲーションビュー
    private var indexNavigationView: some View {
        TeacherIndexView(
            sections: getAvailableDisplaySections(),
            actualSections: getAvailableSections(),
            selectedSection: $selectedSection,
            visibleSection: visibleSection,
            isManualSelection: $isManualSelection
        )
    }
    
    // MARK: - ヘルパーメソッド

    /// インデックスビューを表示するかどうかを判定
    private func shouldShowIndexView(width: CGFloat) -> Bool {
        width > 300 && viewModel.searchText.isEmpty
    }
    
    /// 指定グループにスクロール
    private func scrollToSection(_ section: String?, proxy: ScrollViewProxy) {
        if let section = section {
            withAnimation(.easeInOut(duration: 0.6)) {
                // アンカーポイントにスクロールし、グループ見出しが上部に表示されるようにする
                proxy.scrollTo("anchor_\(section)", anchor: .top)
            }
        }
    }
    
    /// 検索バーをアニメーション付きで表示
    private func showSearchWithAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSearchBar = true
        }
    }
    
    /// 初期データを読み込む
    private func loadInitialData() {
        if viewModel.teachers.isEmpty {
            viewModel.loadTeachers()
        }
    }
    
    /// 選択中のメールアドレスをコピー
    private func copySelectedEmails() {
        viewModel.copySelectedEmails()
        showCopyConfirmation()
    }
    
    /// 個別の教員メールアドレスをコピー
    private func copyTeacherEmail(_ teacher: Teacher) {
        UIPasteboard.general.string = teacher.email
        showCopyConfirmation()
    }
    
    /// コピー確認を表示
    private func showCopyConfirmation() {
        showingCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring()) {
                showingCopyConfirmation = false
            }
        }
    }
    
    /// アニメーション付きで選択をクリア
    private func clearSelectionWithAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.clearSelection()
        }
    }
    
    /// 教員の選択状態を切り替え
    private func toggleTeacherSelection(_ teacher: Teacher) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.toggleSelection(for: teacher)
        }
    }
    
    /// 表示中のグループを更新（見出し位置に基づく）
    private func updateVisibleSection(section: String, geometry: GeometryProxy) {
        let headerY = geometry.frame(in: .global).minY
        // 見出し位置が画面上部150px以内にある場合、そのグループが表示中と判断
        if headerY <= 150 && headerY >= -50 {
            if visibleSection != section {
                withAnimation(.easeInOut(duration: 0.2)) {
                    visibleSection = section
                }
                // ユーザーが手動で選択していた場合、スクロール位置変更で自動追従に戻す
                if isManualSelection {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isManualSelection = false
                        selectedSection = nil
                    }
                }
            }
        }
    }
    
    // 現在表示すべきグループを取得
    private func getSections() -> [String] {
        if viewModel.searchText.isEmpty {
            return japaneseSections
        } else {
            // 検索時は結果を含むグループのみ表示
            return japaneseSections.filter { section in
                guard let teachers = viewModel.teachersBySection[section] else { return false }
                return teachers.contains { teacher in
                    matchesSearch(teacher, query: viewModel.searchText)
                }
            }
        }
    }
    
    // 特定グループの教員を取得
    private func getTeachersForSection(_ section: String) -> [Teacher]? {
        if viewModel.searchText.isEmpty {
            return viewModel.teachersBySection[section]
        } else {
            return viewModel.teachersBySection[section]?.filter { teacher in
                matchesSearch(teacher, query: viewModel.searchText)
            }
        }
    }
    
    /// 教員が検索条件に一致するか確認
    private func matchesSearch(_ teacher: Teacher, query: String) -> Bool {
        teacher.name.localizedCaseInsensitiveContains(query) ||
            (teacher.furigana?.localizedCaseInsensitiveContains(query) ?? false) ||
            teacher.email.localizedCaseInsensitiveContains(query)
    }
    
    /// データのあるグループを取得
    private func getAvailableSections() -> [String] {
        return japaneseSections.filter { section in
            guard let teachers = viewModel.teachersBySection[section] else { return false }
            return !teachers.isEmpty
        }
    }
    
    /// データのある表示グループを取得（「その他」を「#」に置換）
    private func getAvailableDisplaySections() -> [String] {
        return getAvailableSections().map { section in
            return section == "その他" ? "#" : section
        }
    }
}

// MARK: - 再利用可能なコンポーネント

/// 丸型アクションボタン
struct CircleActionButton: View {
    let iconName: String
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: colors[0].opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
    }
}

// MARK: - 状態ビュー

/// エラービュー
struct TeacherErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        StatusView(
            icon: "wifi.exclamationmark",
            iconColors: [.orange, .orange.opacity(0.7)],
            title: "教師情報を読み込めません",
            subtitle: message,
            buttonConfig: StatusButtonConfig(
                title: "再読み込み",
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }
}

/// 検索結果なしビュー
struct TeacherEmptyResultView: View {
    var body: some View {
        StatusView(
            icon: "person.fill.questionmark",
            iconColors: [.gray, .gray.opacity(0.6)],
            title: "一致する教師が見つかりません",
            subtitle: "他のキーワードで検索してください"
        )
    }
}

/// 汎用ステータスビュー
struct StatusView: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    var buttonConfig: StatusButtonConfig? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // テキスト説明
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // オプションボタン
            if let config = buttonConfig {
                Button(action: config.action) {
                    HStack(spacing: 8) {
                        Image(systemName: config.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(config.title)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// ステータスボタン設定
struct StatusButtonConfig {
    let title: String
    let icon: String
    let action: () -> Void
}

// MARK: - コンポーネントビュー

/// 教員検索バー
struct TeacherSearchBar: View {
    @Binding var text: String
    var onClose: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("教師名またはメールアドレスを検索", text: $text)
                    .font(.system(size: 16))
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)
                
                if !text.isEmpty {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            text = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            
            Button(action: {
                isTextFieldFocused = false
                onClose()
            }) {
                Text("キャンセル")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

/// 選択操作バー
struct TeacherSelectionBar: View {
    let selectedCount: Int
    let onCopy: () -> Void
    let onClear: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                
                Text("\(selectedCount)人の教師を選択しました")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                        .foregroundColor(.white)
                }
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.15), value: selectedCount)
                
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thickMaterial)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// 五十音インデックスビュー
struct TeacherIndexView: View {
    let sections: [String]
    let actualSections: [String]
    @Binding var selectedSection: String?
    let visibleSection: String?
    @Binding var isManualSelection: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // ドラッグ状態管理
    @State private var isDragging = false
    @State private var dragLocation: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                Button(action: {
                    selectSection(at: index)
                }) {
                    Text(section)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .foregroundColor(isCurrentSection(index) ? .white : .primary)
                        .background(
                            Circle()
                                .fill(
                                    isCurrentSection(index) ?
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.clear, Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isCurrentSection(index) ? 
                                            Color.clear : 
                                            Color.primary.opacity(isDragging ? 0.3 : 0.15), 
                                            lineWidth: 1
                                        )
                                )
                                .shadow(
                                    color: isCurrentSection(index) ? 
                                    Color.blue.opacity(0.3) : 
                                    Color.clear, 
                                    radius: isCurrentSection(index) ? 4 : 0, 
                                    x: 0, 
                                    y: isCurrentSection(index) ? 2 : 0
                                )
                        )
                        .scaleEffect(isCurrentSection(index) ? 1.1 : 1.0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSection)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: visibleSection)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThickMaterial)
                .stroke(Color.primary.opacity(isDragging ? 0.2 : 0.1), lineWidth: 1)
                .shadow(
                    color: Color.black.opacity(isDragging ? 0.12 : 0.08), 
                    radius: isDragging ? 12 : 8, 
                    x: 0, 
                    y: isDragging ? 6 : 4
                )
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .padding(.trailing, 12)
        .padding(.vertical, 16)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { _ in
                    handleDragEnded()
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
    
    // MARK: - ヘルパーメソッド

    /// 現在のグループかどうかを判定（手動選択を優先、次に表示中のグループ）
    private func isCurrentSection(_ index: Int) -> Bool {
        let actualSection = actualSections[index]
        if isManualSelection {
            return selectedSection == actualSection
        } else {
            return visibleSection == actualSection
        }
    }
    
    /// 指定インデックスのグループを選択
    private func selectSection(at index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedSection = actualSections[index]
            isManualSelection = true
        }
    }
    
    /// ドラッグ変化を処理
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isDragging {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = true
            }
            // 触覚フィードバックを追加
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            // 手動選択状態にマーク
            isManualSelection = true
        }
        
        dragLocation = value.location
        
        // ドラッグ位置に対応するグループを計算
        let sectionIndex = calculateSectionIndex(for: value.location)
        if sectionIndex >= 0 && sectionIndex < actualSections.count {
            let newSection = actualSections[sectionIndex]
            if selectedSection != newSection {
                // 軽い触覚フィードバック
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.prepare()
                selectionFeedback.selectionChanged()
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedSection = newSection
                }
            }
        }
    }
    
    /// ドラッグ終了を処理
    private func handleDragEnded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isDragging = false
        }
    }
    
    /// ドラッグ位置からグループインデックスを計算
    private func calculateSectionIndex(for location: CGPoint) -> Int {
        // 各グループの高さを計算（間隔を含む）
        let itemHeight: CGFloat = 28 + 3
        let topPadding: CGFloat = 8

        // コンテナ上部からの相対位置を計算
        let relativeY = location.y - topPadding
        
        // グループインデックスを計算
        let index = Int(relativeY / itemHeight)
        
        // インデックスが有効範囲内であることを確認
        return max(0, min(index, sections.count - 1))
    }
}

/// 教員行
struct TeacherRow: View {
    let teacher: Teacher
    let isSelected: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 20) {
            // 選択ボタン
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue : .clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? .clear : Color.primary.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            
            // 教員情報
            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let furigana = teacher.furigana {
                    Text(furigana)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // メールアドレスとコピーボタン
                HStack(alignment: .center, spacing: 10) {
                    Text(teacher.email)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    
                    Button(action: onCopy) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.1))
                                    .stroke(.blue.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.15), value: teacher.id)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isSelected ? 
                    (colorScheme == .dark ? 
                     LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing) : 
                     LinearGradient(colors: [.blue.opacity(0.08), .blue.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)) : 
                    LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .stroke(
                    isSelected ? .blue.opacity(0.3) : Color.clear, 
                    lineWidth: isSelected ? 1 : 0
                )
                .shadow(
                    color: isSelected ? .blue.opacity(0.15) : .clear, 
                    radius: isSelected ? 6 : 0, 
                    x: 0, 
                    y: isSelected ? 3 : 0
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onToggle()
        }
    }
}

/// グループ見出しビュー
struct TeacherSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .cornerRadius(1)
            
            Spacer()
        }
        .padding(.leading, -10)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background(.clear)
    }
}

/// 読み込みビュー
struct TeacherLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            VStack(spacing: 8) {
                Text("教師情報を読み込んでいます...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("お待ちください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

/// コピー確認表示
struct TeacherCopyConfirmationView: View {
    let showing: Bool
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        VStack {
            Spacer()
            if showing {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("メールアドレスをコピーしました")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.thickMaterial)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                )
                .scaleEffect(scale)
                .padding(.bottom, 60)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale),
                    removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale)
                ))
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
                .onDisappear {
                    scale = 0.8
                }
            }
        }
    }
}

// MARK: - プレビュー
struct TeacherEmailListView_Previews: PreviewProvider {
    static var previews: some View {
        TeacherEmailListView()
    }
}