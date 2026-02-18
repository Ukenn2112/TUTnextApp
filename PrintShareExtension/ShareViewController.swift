import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    /// 印刷システムがサポートするファイル拡張子
    private static let supportedFileExtensions: Set<String> = [
        "pdf", "jpg", "jpeg", "png", "tiff", "tif", "rtf",
        "xdw", "xbd", "xps", "oxps",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedFile()
    }

    private func handleSharedFile() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            cancelRequest(error: "入力アイテムが見つかりません")
            return
        }

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                #if DEBUG
                print("処理中のアイテムタイプ: \(attachment.registeredTypeIdentifiers)")
                #endif

                if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    Task { await processFileURL(attachment: attachment) }
                    return
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    Task { await processImage(attachment: attachment) }
                    return
                }
            }
        }

        cancelRequest(error: "印刷可能なファイルが見つかりませんでした")
    }

    // MARK: - ファイル処理

    private func processFileURL(attachment: NSItemProvider) async {
        do {
            guard let url = try await attachment.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier
            ) as? URL else {
                cancelRequest(error: "ファイルURLの取得に失敗しました")
                return
            }

            let securityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // ファイル拡張子のバリデーション
            let fileExtension = url.pathExtension.lowercased()
            guard Self.supportedFileExtensions.contains(fileExtension) else {
                cancelRequest(error: "非対応のファイル形式です（.\(fileExtension)）")
                return
            }

            let fileData = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            saveSharedFileAndOpenApp(fileData: fileData, fileName: fileName)
        } catch {
            cancelRequest(error: "ファイル処理エラー: \(error.localizedDescription)")
        }
    }

    private func processImage(attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(
                forTypeIdentifier: UTType.image.identifier
            )

            if let image = item as? UIImage {
                guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                    cancelRequest(error: "画像データの変換に失敗しました")
                    return
                }
                let fileName = "Image_\(Int(Date().timeIntervalSince1970)).jpg"
                saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
            } else if let imageData = item as? Data {
                let fileName = "Image_\(Int(Date().timeIntervalSince1970)).jpg"
                saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
            } else if let imageURL = item as? URL {
                let imageData = try Data(contentsOf: imageURL)
                let fileName = imageURL.lastPathComponent
                saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
            } else {
                cancelRequest(error: "非対応の画像形式です")
            }
        } catch {
            cancelRequest(error: "画像ファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - ファイル保存・アプリ起動

    private func saveSharedFileAndOpenApp(fileData: Data, fileName: String) {
        do {
            guard let sharedContainerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.meikenn.tama"
            ) else {
                cancelRequest(error: "共有コンテナにアクセスできません")
                return
            }

            let tempDirURL = sharedContainerURL.appendingPathComponent(
                "PrintSharedFiles", isDirectory: true)

            // 既存の一時ファイルを全て削除（前回の未アップロードファイルを上書き）
            if FileManager.default.fileExists(atPath: tempDirURL.path) {
                let existingFiles = try FileManager.default.contentsOfDirectory(
                    at: tempDirURL, includingPropertiesForKeys: nil)
                for file in existingFiles {
                    try? FileManager.default.removeItem(at: file)
                }
            }

            try FileManager.default.createDirectory(
                at: tempDirURL, withIntermediateDirectories: true)

            let tempFileURL = tempDirURL.appendingPathComponent(UUID().uuidString)
            try fileData.write(to: tempFileURL)

            let sharedUserDefaults = UserDefaults(suiteName: "group.com.meikenn.tama")
            let fileInfo: [String: Any] = [
                "tempFileURL": tempFileURL.path,
                "fileName": fileName,
                "fileSize": fileData.count,
                "timestamp": Date().timeIntervalSince1970,
            ]
            sharedUserDefaults?.set(fileInfo, forKey: "SharedPrintFile")

            guard let url = URL(string: "tama://print") else {
                cancelRequest(error: "アプリを開くためのURLが無効です")
                return
            }
            openURL(url)
        } catch {
            cancelRequest(error: "ファイル保存エラー: \(error.localizedDescription)")
        }
    }

    private func openURL(_ url: URL) {
        DispatchQueue.main.async { [weak self] in
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:]) { [weak self] success in
                        if success {
                            self?.completeRequest()
                        } else {
                            self?.cancelRequest(error: "アプリを開けませんでした")
                        }
                    }
                    return
                }
                responder = responder?.next
            }
            // UIApplicationが見つからない場合
            self?.completeRequest()
        }
    }

    // MARK: - Extension完了処理

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func cancelRequest(error: String) {
        #if DEBUG
        print("共有エラー: \(error)")
        #endif
        DispatchQueue.main.async {
            let nsError = NSError(
                domain: "com.meikenn.tama.PrintShareExtension",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: error]
            )
            self.extensionContext?.cancelRequest(withError: nsError)
        }
    }
}
