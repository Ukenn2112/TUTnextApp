import SwiftUI
import UniformTypeIdentifiers

// MARK: - PrintSystemView

struct PrintSystemView: View {
    @StateObject private var viewModel = PrintSystemViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    fileSelectionArea
                        .padding(.top, 20)

                    if viewModel.selectedFile != nil {
                        printSettingsArea
                        uploadButton
                    }

                    if viewModel.selectedFile == nil && !viewModel.recentUploads.isEmpty {
                        recentUploadsArea
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("印刷システム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
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
            if viewModel.isLoading {
                LoadingView()
            }
        }
    }

    // MARK: - File Selection

    private var fileSelectionArea: some View {
        Group {
            if let selectedFile = viewModel.selectedFile {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))

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
                    .tint(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
                }
                .padding()
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            } else {
                fileSelectButton
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
            .tint(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
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
            .background(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255), in: RoundedRectangle(cornerRadius: 12))
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
        .padding()
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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

            ForEach(viewModel.recentUploads, id: \.printNumber) { result in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))

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
        }
        .padding()
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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
            .tint(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
        } else {
            Button {
                viewModel.uploadFile()
            } label: {
                Text("アップロード")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255), in: RoundedRectangle(cornerRadius: 12))
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
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
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
                                showCopiedAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
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
                .padding()
                .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                closeButton
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
            .navigationTitle("アップロード完了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
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
            .tint(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255))
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
                    .background(Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255), in: RoundedRectangle(cornerRadius: 12))
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
