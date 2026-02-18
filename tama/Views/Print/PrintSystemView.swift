import SwiftUI
import UniformTypeIdentifiers

struct PrintSystemView: View {
    @StateObject private var viewModel = PrintSystemViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // URLスキームで起動された場合のビュー生成関数
    static func handleURLScheme() -> some View {
        return PrintSystemView()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                // メインコンテンツ
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView
                        .background(colorScheme == .dark ? Color.black : Color.white)

                    // コンテンツエリア
                    ScrollView {
                        VStack(spacing: 20) {
                            // ファイル選択エリア
                            fileSelectionArea
                                .padding(.top, 20)

                            // ファイルが選択されている場合、印刷設定を表示
                            if viewModel.selectedFile != nil {
                                printSettingsArea
                            }

                            // 最近のアップロード履歴（ファイルが選択されていない場合のみ表示）
                            if viewModel.selectedFile == nil && !viewModel.recentUploads.isEmpty {
                                recentUploadsArea
                            }

                            // エラーメッセージ
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.center)
                            }

                            // アップロードボタン（ファイルが選択されている場合のみ表示）
                            if viewModel.selectedFile != nil {
                                uploadButton
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 画面表示時に自動的にログイン
            viewModel.login { _ in
                // ログイン成功後に最近のアップロード履歴を読み込み
                viewModel.loadRecentUploads()
            }
        }
        .sheet(isPresented: $viewModel.showFileSelector) {
            // ファイル選択画面
            DocumentPicker(
                supportedTypes: viewModel.supportedDocumentTypes(),
                onDocumentsPicked: { urls in
                    if let url = urls.first {
                        viewModel.handleImportedFile(url: url)
                    }
                })
        }
        .sheet(isPresented: $viewModel.showResultView) {
            // 結果表示画面
            if let result = viewModel.printResult {
                PrintResultView(
                    result: result,
                    onDismiss: {
                        viewModel.reset()
                    })
            }
        }
        .overlay {
            // ローディング表示
            if viewModel.isLoading {
                LoadingView()
            }
        }
    }

    // ヘッダービュー
    private var headerView: some View {
        HStack {
            // 戻るボタン
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)

            Spacer()

            // タイトル
            Text("印刷システム")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // 右側のスペーサー（バランス用）
            Color.clear
                .frame(width: 44, height: 44)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
    }

    // ファイル選択エリア
    private var fileSelectionArea: some View {
        VStack(spacing: 12) {
            // ファイル選択ボタンまたは選択済みファイル情報
            if let selectedFile = viewModel.selectedFile {
                // 選択済みファイル情報
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedFile.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(viewModel.formattedFileSize(bytes: selectedFile.size))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // ファイル変更ボタン
                        Button(action: {
                            viewModel.selectFile()
                        }) {
                            Text("変更")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
            } else {
                // ファイル選択ボタン
                Button(action: {
                    viewModel.selectFile()
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))

                        Text("ファイルを選択")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }

    // 印刷設定エリア
    private var printSettingsArea: some View {
        VStack(spacing: 20) {
            // タイトル
            Text("印刷設定")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 設定項目
            VStack(spacing: 16) {
                // まとめて1枚の設定
                settingRow(title: NSLocalizedString("まとめて1枚", comment: "")) {
                    Picker("", selection: $viewModel.printSettings.nUp) {
                        ForEach(NUpType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 両面印刷の設定
                settingRow(title: NSLocalizedString("両面印刷", comment: "")) {
                    Picker("", selection: $viewModel.printSettings.plex) {
                        ForEach(PlexType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 開始ページの設定
                settingRow(title: NSLocalizedString("開始ページ", comment: "")) {
                    HStack {
                        Text("\(viewModel.printSettings.startPage)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40)

                        Spacer()

                        Stepper("", value: $viewModel.printSettings.startPage, in: 1...999)
                            .labelsHidden()
                    }
                }

                // 暗証番号の設定
                settingRow(title: NSLocalizedString("暗証番号（オプション）", comment: "")) {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("暗証番号を入力", text: $viewModel.pinCode)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.pinCode) { _, newValue in
                                // 数字以外の文字を削除
                                let filtered = newValue.filter { $0.isNumber }
                                // 4桁を超える場合は切り捨て
                                if filtered.count > 4 {
                                    viewModel.pinCode = String(filtered.prefix(4))
                                } else {
                                    viewModel.pinCode = filtered
                                }
                            }

                        Spacer()

                        Text("※ 暗証番号を設定すると、印刷時に暗証番号の入力が必要になります")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    // 設定行の共通レイアウト
    private func settingRow<Content: View>(title: String, @ViewBuilder content: () -> Content)
        -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            content()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }

    // 最近のアップロード履歴エリア
    private var recentUploadsArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のアップロード")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            ForEach(viewModel.recentUploads, id: \.printNumber) { result in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.fileName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text("予約番号: \(result.printNumber)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(result.formattedExpiryDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    // アップロードボタン
    private var uploadButton: some View {
        Button(action: {
            viewModel.uploadFile()
        }) {
            Text("アップロード")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// 印刷結果表示ビュー
struct PrintResultView: View {
    let result: PrintResult
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 成功メッセージ
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .padding(.bottom, 10)

                    Text("印刷ファイルのアップロードが完了しました")
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)

                    Text("以下の情報を確認してください")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 結果詳細
                VStack(spacing: 16) {
                    // プリント予約番号（コピーボタン付き）
                    HStack {
                        Text("プリント予約番号")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)

                        Spacer()

                        HStack(spacing: 8) {
                            Text(result.printNumber)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            Button(action: {
                                UIPasteboard.general.string = result.printNumber
                                showCopiedAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    // その他の情報
                    resultItemView(
                        title: NSLocalizedString("ファイル名", comment: ""), value: result.fileName)
                    resultItemView(
                        title: NSLocalizedString("有効期限", comment: ""), value: result.formattedExpiryDate)
                    resultItemView(
                        title: NSLocalizedString("ページ数", comment: ""), value: "\(result.pageCount)")
                    resultItemView(
                        title: NSLocalizedString("両面", comment: ""), value: result.duplex)
                    resultItemView(
                        title: NSLocalizedString("サイズ", comment: ""), value: result.fileSize)
                    resultItemView(
                        title: NSLocalizedString("まとめて1枚", comment: ""), value: result.nUp)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // 閉じるボタン
                Button(action: {
                    dismiss()
                    onDismiss()
                }) {
                    Text("閉じる")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarTitle("アップロード完了", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .overlay {
                if showCopiedAlert {
                    VStack {
                        Text("コピーしました")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showCopiedAlert = false
                            }
                        }
                    }
                }
            }
        }
    }

    // 結果項目のビュー
    private func resultItemView(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// ドキュメントピッカー
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
            // セキュリティスコープの開始
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    print("セキュリティスコープへのアクセスに失敗しました")
                    continue
                }

                // ファイルの処理
                parent.onDocumentsPicked([url])

                // セキュリティスコープの終了
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

// ローディングビュー
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                Text("処理中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground).opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    PrintSystemView()
}
