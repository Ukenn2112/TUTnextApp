import SwiftUI

// MARK: - メインビュー
struct TeacherEmailListView: View {
    @StateObject private var viewModel = TeacherEmailListViewModel()
    @State private var showingCopyConfirmation = false
    /// 「コピーしました」を隠すタイマー。続けてコピーしたら前のタイマーを取り消し、表示時間を数え直す
    @State private var copyConfirmationTask: Task<Void, Never>?
    @State private var selectedSection: String?
    @State private var showSearchBar = false
    @State private var visibleSection: String?
    /// 五十音インデックスを指でなぞっている最中か（この間は指の下のグループを優先して強調する）
    @State private var isIndexDragging = false
    /// 読み込み中にスケルトンが実際に出たか。出ていなければ一覧は切り替えのアニメーションなしで出す
    @State private var loadingSkeletonShown = false
    /// 直前まで出していた本体の種類。切り替わりの瞬間に「どこから切り替わったか」を知るために持つ
    @State private var settledPhase: ContentPhase = .loading
    @Environment(\.dismiss) private var dismiss
    
    // 五十音行
    private let japaneseSections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "その他"]
    
    // 表示用の五十音行（「その他」を「#」に置換）
    private let displaySections = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "#"]

    // 見出し位置の基準にする座標空間（教員一覧のスクロールビュー自身。0がスクロール領域の上端）。
    // 画面全体や画面の上端を基準にすると、上のヘッダー（検索バー・選択バー）の高さで判定位置がずれるため
    private static let coordinateSpaceName = "teacherEmailList"

    // 見出しがこの範囲（スクロール領域の上端からの距離）にあるグループを表示中とみなす。
    // 上端より少し下（2行ほど）まで来たら表示中にし、見出しが上へ抜けても1行と少しの間は保つ。
    // 以前の基準（画面上端からの -50〜150。ヘッダーの高さは約80）をスクロール領域の上端基準に直した値
    private static let visibleHeaderRange: ClosedRange<CGFloat> = -130...70

    // MARK: - ボディ
    // シートの中で画面遷移はしないので NavigationStack は使わない。
    // 使うと最初のレイアウトでナビゲーションバーの高さが確保され、バーを隠した直後に中身が上へずれる
    var body: some View {
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
        .onAppear(perform: loadInitialData)
    }
    
    // MARK: - 背景ビュー
    private var backgroundView: some View {
        // 地の色はどのページも同じ白（暗い外観では黒）。
        // 以前はここだけ上から下へのグラデーションだったが、ページごとに地の色が変わって見えるため揃えた
        CardSurface.pageFill
            .ignoresSafeArea()
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
                withMotion(Motion.standard) {
                    showSearchBar = false
                    viewModel.searchText = ""
                }
            }
            .motionTransition(.slide(.trailing))
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
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                CircleActionButton(
                    iconName: "magnifyingglass",
                    colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                    action: { showSearchWithAnimation() }
                )
                
                CircleActionButton(
                    iconName: "xmark",
                    colors: [.gray, .gray.opacity(0.8)],
                    action: { dismiss() }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .motionTransition(.slide(.leading))
    }
    
    // MARK: - 選択バービュー
    private var selectionBarView: some View {
        TeacherSelectionBar(
            selectedCount: viewModel.selectedTeachers.count,
            onCopy: copySelectedEmails,
            onClear: clearSelectionWithAnimation
        )
        .motionTransition(.rise)
    }
    
    // MARK: - コンテンツビュー
    // データが届いて出てくる中身（一覧・エラー・検索結果なし）はクロスフェードだけで入れ替える
    private var contentView: some View {
        ZStack {
            switch contentPhase {
            case .loading:
                TeacherLoadingView(skeletonShown: $loadingSkeletonShown)
                    .motionTransition(.fade)
            case .failure:
                TeacherErrorView(message: viewModel.errorMessage ?? "", onRetry: viewModel.loadTeachers)
                    .motionTransition(.fade)
            case .noResults:
                TeacherEmptyResultView()
                    .motionTransition(.fade)
            case .list:
                teacherListView
                    .motionTransition(.fade)
            }
        }
        // スケルトンが出る前に読み込みが終わったときは、切り替えをアニメーションさせずにそのまま出す。
        // 本体の種類が変わったときだけ手を入れる（スケルトン自体の出方など、ほかの動きには触れない）
        .transaction(value: contentPhase) { transaction in
            if settledPhase == .loading && !loadingSkeletonShown {
                transaction.animation = nil
            }
        }
        .motionAnimation(Motion.standard, value: contentPhase)
        .onChange(of: contentPhase) { _, newPhase in
            settledPhase = newPhase
            if newPhase == .loading {
                loadingSkeletonShown = false
            }
        }
        .zIndex(0)
    }

    /// 本体に何を出しているか（切り替わりのアニメーションのきっかけにする）
    private enum ContentPhase: Equatable {
        case loading, failure, noResults, list
    }

    /// 最初の読み込みが終わるまでは読み込み中として扱う（開いた直後に空の一覧を一瞬出さない）
    private var contentPhase: ContentPhase {
        if viewModel.isLoading || !viewModel.hasLoadedOnce {
            return .loading
        } else if viewModel.errorMessage != nil {
            return .failure
        } else if viewModel.filteredTeachers.isEmpty && !viewModel.searchText.isEmpty {
            return .noResults
        } else {
            return .list
        }
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
                                                .onChange(
                                                    of: geometry.frame(in: .named(Self.coordinateSpaceName)).minY
                                                ) { _, _ in
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
                .readableWidth()
            }
            .coordinateSpace(.named(Self.coordinateSpaceName))
            .onChange(of: selectedSection) { _, newSection in
                scrollToSection(newSection, proxy: scrollProxy)
            }
            .onChange(of: isIndexDragging) { _, isDragging in
                if !isDragging {
                    finishIndexDragging()
                }
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
            isDragging: $isIndexDragging
        )
    }
    
    // MARK: - ヘルパーメソッド

    /// インデックスビューを表示するかどうかを判定
    private func shouldShowIndexView(width: CGFloat) -> Bool {
        width > 300 && viewModel.searchText.isEmpty
    }
    
    /// 指定グループにスクロール。
    /// インデックスをなぞる指に一覧が遅れないよう、アニメーションなしで一気に移す（標準の索引と同じ）
    private func scrollToSection(_ section: String?, proxy: ScrollViewProxy) {
        guard let section else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            // アンカーポイントにスクロールし、グループ見出しが上部に表示されるようにする
            proxy.scrollTo("anchor_\(section)", anchor: .top)
        }
    }

    /// インデックスから指が離れたら、スクロール位置に合わせた強調へ戻す。
    /// 指の下のグループは一覧の上端に来ているので、表示中のグループもそれに揃えてちらつかせない
    private func finishIndexDragging() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let selectedSection {
                visibleSection = selectedSection
            }
            // 次に同じグループを選んだときもスクロールが起きるよう、選択は空に戻す
            selectedSection = nil
        }
    }
    
    /// 検索バーをアニメーション付きで表示
    private func showSearchWithAnimation() {
        withMotion(Motion.standard) {
            showSearchBar = true
        }
    }
    
    /// 初期データを読み込む
    private func loadInitialData() {
        if viewModel.teachers.isEmpty && !viewModel.isLoading {
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
        withMotion(Motion.standard) {
            showingCopyConfirmation = true
        }
        copyConfirmationTask?.cancel()
        copyConfirmationTask = Task { @MainActor in
            try? await Task.sleep(for: Self.copyConfirmationDuration)
            guard !Task.isCancelled else { return }
            withMotion(Motion.standard) {
                showingCopyConfirmation = false
            }
        }
    }

    /// 「コピーしました」を出しておく時間
    private static let copyConfirmationDuration: Duration = .seconds(2.5)
    
    /// アニメーション付きで選択をクリア
    private func clearSelectionWithAnimation() {
        withMotion(Motion.quick) {
            viewModel.clearSelection()
        }
    }
    
    /// 教員の選択状態を切り替え
    private func toggleTeacherSelection(_ teacher: Teacher) {
        withMotion(Motion.quick) {
            viewModel.toggleSelection(for: teacher)
        }
    }
    
    /// 表示中のグループを更新（見出し位置に基づく）
    private func updateVisibleSection(section: String, geometry: GeometryProxy) {
        let headerY = geometry.frame(in: .named(Self.coordinateSpaceName)).minY
        // 見出しがスクロール領域の上端付近にある場合、そのグループが表示中と判断
        guard Self.visibleHeaderRange.contains(headerY), visibleSection != section else { return }
        if visibleSection == nil || isIndexDragging {
            // 最初の1回（一覧が出た直後）とインデックスをなぞっている間は、強調を動かさずに切り替える
            visibleSection = section
        } else {
            withMotion(Motion.quick) {
                visibleSection = section
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
                .foregroundStyle(.white)
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
    var buttonConfig: StatusButtonConfig?
    
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
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                                    colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.appPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("教師名またはメールアドレスを検索", text: $text)
                    .font(.system(size: 16))
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)
                
                if !text.isEmpty {
                    Button(action: {
                        withMotion(Motion.quick) {
                            text = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .motionTransition(.fade)
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
                    .foregroundStyle(Color.appPrimary)
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

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
                
                Text("\(selectedCount)人の教師を選択しました")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    // 人数が変わると数字だけが入れ替わる
                    .contentTransition(.numericText())
                    .motionAnimation(Motion.quick, value: selectedCount)
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
                                        colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.appPrimary.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                        .foregroundStyle(.white)
                }
                
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
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
        // 輪郭はアプリ共通のカードと同じ（地の色＋1ptの枠）で取る
        .background(
            RoundedRectangle(cornerRadius: CardSurface.cornerRadius)
                .fill(CardSurface.pageFill)
                .stroke(CardSurface.outlineStroke, lineWidth: CardSurface.outlineWidth)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// 五十音インデックスビュー。
///
/// 標準の索引（UITableView のセクションインデックス）と同じく、指を置いた・なぞった位置のグループへ
/// すぐに移る。ボタンは使わず、索引全体に1つだけ付けたドラッグで指の位置からグループを求める
struct TeacherIndexView: View {
    let sections: [String]
    let actualSections: [String]
    @Binding var selectedSection: String?
    let visibleSection: String?
    /// 指で索引をなぞっている最中か（親はこの間、スクロール位置による強調の切り替えをしない）
    @Binding var isDragging: Bool

    /// 実際に描かれた索引の高さ（内側の余白を含む）。指の位置からグループを求めるのに使う
    @State private var barHeight: CGFloat = 0
    /// 触覚を返すきっかけ。指の下のグループが変わるたびに変わる（離しても空には戻さない）
    @State private var hapticSection: String?

    /// 1文字ぶんの丸の大きさ
    private static let itemSize: CGFloat = 28
    /// 丸どうしの間隔
    private static let itemSpacing: CGFloat = 3
    /// 索引の内側の上下の余白
    private static let innerVerticalPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: Self.itemSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                indexItem(section, index: index)
            }
        }
        .padding(.vertical, Self.innerVerticalPadding)
        .padding(.horizontal, 6)
        // 一覧の上に浮くが、輪郭はアプリ共通のカードと同じ（地の色＋1ptの枠）で取る。
        // 塗りが地の色そのものなので、下を行が流れていても読み違えない
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(CardSurface.pageFill)
                .stroke(CardSurface.outlineStroke, lineWidth: CardSurface.outlineWidth)
        )
        // 指の位置はこの索引自身の座標で受け取る（外側の余白を含めない）ので、測った高さとそのまま比べられる
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            barHeight = height
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(at: value.location.y)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .selectionHaptic(trigger: hapticSection)
        .onDisappear {
            // なぞっている途中で索引が消えても（検索を始めたなど）、なぞり中のままにしない
            if isDragging {
                isDragging = false
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 16)
    }

    /// 索引の1文字。強調は塗りと文字色だけで示し、大きさは変えない
    private func indexItem(_ section: String, index: Int) -> some View {
        let isCurrent = isCurrentSection(index)
        return Text(section)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: Self.itemSize, height: Self.itemSize)
            .foregroundStyle(isCurrent ? Color.white : Color.primary)
            .background(
                Circle()
                    .fill(
                        isCurrent ?
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
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
                                // なぞっている間は枠を少し濃くする（色だけ変える）
                                isCurrent ? Color.clear : Color.primary.opacity(isDragging ? 0.3 : 0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isCurrent ? Color.appPrimary.opacity(0.3) : Color.clear,
                        radius: isCurrent ? 4 : 0,
                        x: 0,
                        y: isCurrent ? 2 : 0
                    )
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if index < actualSections.count {
                    selectedSection = actualSections[index]
                }
            }
    }

    // MARK: - ヘルパーメソッド

    /// 現在のグループかどうかを判定（なぞっている間は指の下のグループ、それ以外は表示中のグループ）
    private func isCurrentSection(_ index: Int) -> Bool {
        guard index < actualSections.count else { return false }
        let actualSection = actualSections[index]
        return isDragging ? selectedSection == actualSection : visibleSection == actualSection
    }

    /// 指の位置の変化を処理する。指を置いただけ（動かしていない）でも、その下のグループを選ぶ。
    /// 強調は指にぴったり付いてくるよう、アニメーションなしで切り替える
    private func handleDragChanged(at locationY: CGFloat) {
        guard let index = sectionIndex(at: locationY) else { return }
        let newSection = actualSections[index]
        if !isDragging {
            isDragging = true
        }
        if selectedSection != newSection {
            selectedSection = newSection
            hapticSection = newSection
        }
    }

    /// 指の縦位置（索引自身の座標）からグループの番号を求める。範囲外は端のグループに丸める
    private func sectionIndex(at locationY: CGFloat) -> Int? {
        let count = actualSections.count
        guard count > 0, barHeight > 0 else { return nil }
        let usableHeight = barHeight - Self.innerVerticalPadding * 2
        // 1文字ぶんの送り幅（丸＋間隔）。最後の丸の後ろにも間隔があるとみなして等分する
        let pitch = (usableHeight + Self.itemSpacing) / CGFloat(count)
        guard pitch > 0 else { return nil }
        let rawIndex = Int(floor((locationY - Self.innerVerticalPadding) / pitch))
        return min(max(rawIndex, 0), count - 1)
    }
}

/// 教員行
struct TeacherRow: View {
    let teacher: Teacher
    let isSelected: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void

    // 選ばれているかどうかは塗り・枠の色だけで示す（大きさは変えない）
    var body: some View {
        HStack(spacing: 20) {
            // 選択ボタン
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appPrimary : .clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? .clear : Color.primary.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: isSelected ? Color.appPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // 教員情報
            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if let furigana = teacher.furigana {
                    Text(furigana)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                // メールアドレスとコピーボタン
                HStack(alignment: .center, spacing: 10) {
                    Text(teacher.email)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appPrimary)
                        .lineLimit(1)
                    
                    Button(action: onCopy) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.appPrimary.opacity(0.1))
                                    .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
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
                    LinearGradient(
                        colors: isSelected
                            ? [Color.appPrimary.opacity(0.10), Color.appPrimary.opacity(0.07)]
                            : [Color.clear, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // 選ばれている行は色の付いた塗りと枠だけで示す（影では浮かせない）
                .stroke(
                    isSelected ? Color.appPrimary.opacity(0.3) : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .motionAnimation(Motion.quick, value: isSelected)
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
                        colors: [Color.appPrimary.opacity(0.6), Color.appPrimary.opacity(0.2)],
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

/// 読み込みビュー。
///
/// 教員の行と同じ形を塗りつぶしたスケルトンを並べる。読み込みが `Motion.skeletonDelay` より
/// 長く続いたときだけ出し（すぐ読み込めたときのちらつきを防ぐ）、きらめきは入れ物に1回だけ掛ける
struct TeacherLoadingView: View {
    /// スケルトンを実際に出したら `true` にする（親はこれを見て、一覧への切り替えをアニメーションさせるか決める）
    @Binding var skeletonShown: Bool

    /// スケルトンの仮の教員（`.redacted` で塗りつぶすので文字は画面に出ない。id は固定）
    private static let placeholderTeachers: [Teacher] = (0..<8).map { index in
        Teacher(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID(),
            name: index.isMultiple(of: 2) ? "多摩 太郎" : "聖蹟 花子",
            furigana: index.isMultiple(of: 2) ? "たま たろう" : "せいせき はなこ",
            email: index.isMultiple(of: 2) ? "tama.taro@tama.ac.jp" : "seiseki@tama.ac.jp"
        )
    }

    var body: some View {
        DelayedSkeletonGate(isLoading: true) { showsSkeleton in
            if showsSkeleton {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        TeacherSectionHeader(title: "あ")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        ForEach(Self.placeholderTeachers) { teacher in
                            TeacherRow(teacher: teacher, isSelected: false, onToggle: {}, onCopy: {})
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.top, 16)
                    .readableWidth()
                }
                .scrollDisabled(true)
                .skeleton(true)
                .onAppear {
                    skeletonShown = true
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// コピー確認表示
struct TeacherCopyConfirmationView: View {
    let showing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if showing {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("メールアドレスをコピーしました")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(.thickMaterial)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                )
                .padding(.bottom, 60)
                // 表示・非表示の速さは呼び出し側の withMotion で決める
                .motionTransition(.rise)
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
