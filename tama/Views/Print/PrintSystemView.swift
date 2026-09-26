import SwiftUI
import UniformTypeIdentifiers

// MARK: - PrintSystemView

struct PrintSystemView: View {
    @StateObject private var viewModel = PrintSystemViewModel()
    @Environment(\.dismiss) private var dismiss

    /// ファイルを選んであるか。ファイル本体（タプル）は比較できないので、アニメーションの基準にはこれを使う
    private var hasSelectedFile: Bool { viewModel.selectedFile != nil }

    /// 最近のアップロード欄を出すか（読み込み中は仮の行を出す）
    private var showsRecentUploads: Bool {
        !hasSelectedFile && (viewModel.isLoadingRecentUploads || !viewModel.recentUploads.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    fileSelectionArea
                        .padding(.top, 20)

                    if hasSelectedFile {
                        printSettingsArea
                            .motionTransition(.rise)
                        uploadButton
                            .motionTransition(.rise)
                    }

                    if showsRecentUploads {
                        recentUploadsArea
                            .motionTransition(.fade)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .motionTransition(.rise)
                    }
                }
                // ファイルの選択・取り消しで内容が入れ替わるときと、エラーの出入りをそろえて動かす
                .motionAnimation(Motion.standard, value: hasSelectedFile)
                .motionAnimation(Motion.quick, value: viewModel.errorMessage)
                .motionAnimation(Motion.standard, value: viewModel.isLoadingRecentUploads)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .readableWidth()
            }
            .navigationTitle("印刷システム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .onAppear {
            viewModel.login { _ in
                viewModel.loadRecentUploads()
            }
        }
        .sheet(isPresented: $viewModel.showFileSelector) {
            DocumentPicker(
                supportedTypes: viewModel.supportedDocumentTypes(),
                onDocumentsPicked: { urls in
                    if let url = urls.first {
                        viewModel.handleImportedFile(url: url)
                    }
                }
            )
        }
        .sheet(isPresented: $viewModel.showResultView) {
            if let result = viewModel.printResult {
                PrintResultView(result: result) {
                    viewModel.reset()
                }
            }
        }
        .overlay {
            ZStack {
                if viewModel.isLoading {
                    LoadingView()
                        .motionTransition(.fade)
                }
            }
            .motionAnimation(Motion.quick, value: viewModel.isLoading)
        }
    }

    // MARK: - File Selection

    private var fileSelectionArea: some View {
        Group {
            if let selectedFile = viewModel.selectedFile {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedFile.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(viewModel.formattedFileSize(bytes: selectedFile.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("変更") {
                        viewModel.selectFile()
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(Color.appPrimary)
                }
                .outlinedCard()
                .motionTransition(.swap)
            } else {
                fileSelectButton
                    .motionTransition(.swap)
            }
        }
    }

    @ViewBuilder
    private var fileSelectButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                viewModel.selectFile()
            } label: {
                Label("ファイルを選択", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.appPrimary)
        } else {
            Button {
                viewModel.selectFile()
            } label: {
                Label("ファイルを選択", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(Color.appPrimary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Print Settings

    private var printSettingsArea: some View {
        VStack(spacing: 20) {
            Text("印刷設定")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                settingRow(title: "まとめて1枚") {
                    Picker("まとめて1枚", selection: $viewModel.printSettings.nUp) {
                        ForEach(NUpType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                settingRow(title: "両面印刷") {
                    Picker("両面印刷", selection: $viewModel.printSettings.plex) {
                        ForEach(PlexType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                settingRow(title: "開始ページ") {
                    HStack {
                        Text("\(viewModel.printSettings.startPage)")
                            .font(.subheadline.weight(.medium))
                            .frame(width: 40)

                        Spacer()

                        Stepper("開始ページ", value: $viewModel.printSettings.startPage, in: 1...999)
                            .labelsHidden()
                    }
                }

                settingRow(title: "暗証番号（オプション）") {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("暗証番号を入力", text: $viewModel.pinCode)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.pinCode) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                viewModel.pinCode = filtered.count > 4
                                    ? String(filtered.prefix(4))
                                    : filtered
                            }

                        Spacer()

                        Text("※ 暗証番号を設定すると、印刷時に暗証番号の入力が必要になります")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .outlinedCard()
    }

    private func settingRow<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            content()
                .frame(maxWidth: .infinity)
                .padding()
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Recent Uploads

    private var recentUploadsArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のアップロード")
                .font(.subheadline.weight(.semibold))

            if viewModel.isLoadingRecentUploads {
                // 読み込みが長引いたときだけ仮の行を出す（すぐ読み込めたときはちらつかせない）
                DelayedSkeletonGate(isLoading: viewModel.isLoadingRecentUploads) { showsSkeleton in
                    VStack(spacing: 12) {
                        ForEach(0..<Self.placeholderRowCount, id: \.self) { _ in
                            recentUploadPlaceholderRow
                        }
                    }
                    .skeleton(showsSkeleton)
                    .opacity(showsSkeleton ? 1 : 0)
                }
            } else {
                ForEach(viewModel.recentUploads, id: \.printNumber) { result in
                    recentUploadRow(result)
                        .motionTransition(.fade)
                }
            }
        }
        .outlinedCard()
    }

    /// 読み込み中に出す仮の行の数
    private static let placeholderRowCount = 2

    private func recentUploadRow(_ result: PrintResult) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.appPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text("予約番号: \(result.printNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(result.formattedExpiryDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 読み込み中の仮の行（本物の行と同じ形。文字は `.redacted` で塗りつぶされる）
    private var recentUploadPlaceholderRow: some View {
        HStack {
            SkeletonBlock(width: 18, height: 22, cornerRadius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Document.pdf")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(verbatim: "000000000")
                    .font(.caption)
            }

            Spacer()

            Text(verbatim: "0000/00/00")
                .font(.caption2)
        }
        .padding()
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Upload Button

    @ViewBuilder
    private var uploadButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                viewModel.uploadFile()
            } label: {
                Text("アップロード")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 10)
            .tint(Color.appPrimary)
        } else {
            Button {
                viewModel.uploadFile()
            } label: {
                Text("アップロード")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - PrintResultView

struct PrintResultView: View {
    let result: PrintResult
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCopiedAlert = false

    /// 完了のチェックマークを描き始めたか（画面に出たときに一度だけ動かす）
    @State private var showsCheckmark = false

    /// 「コピーしました」を出しておく時間
    private static let copiedToastDuration: Duration = .seconds(1.5)

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    completionCheckmark
                        .padding(.bottom, 10)

                    Text("印刷ファイルのアップロードが完了しました")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("以下の情報を確認してください")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    HStack {
                        Text("プリント予約番号")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .leading)

                        Spacer()

                        HStack(spacing: 8) {
                            Text(result.printNumber)
                                .font(.subheadline.weight(.medium))

                            Button {
                                UIPasteboard.general.string = result.printNumber
                                withMotion(Motion.quick) {
                                    showCopiedAlert = true
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }

                    resultRow(title: "ファイル名", value: result.fileName)
                    resultRow(title: "有効期限", value: result.formattedExpiryDate)
                    resultRow(title: "ページ数", value: "\(result.pageCount)")
                    resultRow(title: "両面", value: result.duplex)
                    resultRow(title: "サイズ", value: result.fileSize)
                    resultRow(title: "まとめて1枚", value: result.nUp)
                }
                .outlinedCard()
                .padding(.horizontal)

                Spacer()

                closeButton
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
            .navigationTitle("アップロード完了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetCloseButton {
                        dismiss()
                        onDismiss()
                    }
                }
            }
            .overlay {
                if showCopiedAlert {
                    Text("コピーしました")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                        .motionTransition(.fade)
                        .task {
                            try? await Task.sleep(for: Self.copiedToastDuration)
                            guard !Task.isCancelled else { return }
                            withMotion(Motion.quick) {
                                showCopiedAlert = false
                            }
                        }
                }
            }
        }
        .onAppear {
            // 「視差効果を減らす」が有効なら、描画もはずみも付けずにそのまま出す
            if reduceMotion {
                showsCheckmark = true
            } else {
                withMotion(Motion.emphasized) {
                    showsCheckmark = true
                }
            }
        }
    }

    /// 完了のチェックマーク。
    /// iOS 26 以降は線を描くように現れ、それ以前は出たときに一度だけ弾む。
    /// どちらも場所は最初から確保しておき、現れるときに周りの文字が動かないようにする
    private var completionCheckmark: some View {
        let symbol = Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 60))
            .foregroundStyle(.green)
            .accessibilityHidden(true)

        return ZStack {
            symbol.hidden()

            if #available(iOS 26.0, *) {
                if showsCheckmark {
                    if reduceMotion {
                        symbol
                    } else {
                        symbol
                            .transition(.symbolEffect(.drawOn))
                    }
                }
            } else {
                symbol
                    .symbolEffect(.bounce, value: reduceMotion ? false : showsCheckmark)
            }
        }
    }

    private func resultRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                dismiss()
                onDismiss()
            } label: {
                Text("閉じる")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.appPrimary)
        } else {
            Button {
                dismiss()
                onDismiss()
            } label: {
                Text("閉じる")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - DocumentPicker

struct DocumentPicker: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController, context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
        ) {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                parent.onDocumentsPicked([url])
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

// MARK: - LoadingView

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text("処理中...")
                    .font(.subheadline.weight(.medium))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    PrintSystemView()
}
