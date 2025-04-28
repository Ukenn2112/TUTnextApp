//
//  ShareViewController.swift
//  PrintShareExtension
//
//  Created by 维安雨轩 on 2025/04/01.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedFile()
    }

    private func handleSharedFile() {
        // 共有されたファイルを取得
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest(error: "入力アイテムが見つかりません")
            return
        }

        var hasProcessedFile = false

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                print("処理中のアイテムタイプ: \(attachment.registeredTypeIdentifiers)")

                // ファイルURLの処理
                if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    processFileURL(attachment: attachment)
                    hasProcessedFile = true
                    return
                }

                // 画像の処理（相册共有時はこちらが実行される）
                else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    processImage(attachment: attachment)
                    hasProcessedFile = true
                    return
                }
            }
        }

        if !hasProcessedFile {
            completeRequest(error: "印刷可能なファイルが見つかりませんでした")
        }
    }

    // ファイルURLの処理
    private func processFileURL(attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
            [weak self] item, error in
            guard let url = item as? URL else {
                self?.completeRequest(error: "ファイルURLの取得に失敗しました")
                return
            }

            // セキュリティスコープのアクセス開始
            let securityScoped = url.startAccessingSecurityScopedResource()

            do {
                // ファイルデータを読み込む
                let fileData = try Data(contentsOf: url)
                let fileName = url.lastPathComponent

                // 共有されたファイルを保存
                self?.saveSharedFileAndOpenApp(fileData: fileData, fileName: fileName)

                // セキュリティスコープを停止
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            } catch {
                // セキュリティスコープを停止
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
                self?.completeRequest(error: "ファイル処理エラー: \(error.localizedDescription)")
            }
        }
    }

    // 画像の処理
    private func processImage(attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) {
            [weak self] item, error in
            // UIImageデータの場合
            if let image = item as? UIImage {
                // JPEGに変換
                guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                    self?.completeRequest(error: "画像データの変換に失敗しました")
                    return
                }

                // ファイル名を生成
                let fileName = "Image_\(Int(Date().timeIntervalSince1970)).jpg"

                // 共有されたファイルを保存
                self?.saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
                return
            }

            // NSDataの場合
            if let imageData = item as? Data {
                // ファイル名を生成
                let fileName = "Image_\(Int(Date().timeIntervalSince1970)).jpg"

                // 共有されたファイルを保存
                self?.saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
                return
            }

            // URLの場合（ローカルファイルURL）
            if let imageURL = item as? URL {
                do {
                    let imageData = try Data(contentsOf: imageURL)
                    let fileName = imageURL.lastPathComponent

                    // 共有されたファイルを保存
                    self?.saveSharedFileAndOpenApp(fileData: imageData, fileName: fileName)
                } catch {
                    self?.completeRequest(
                        error: "画像ファイルの読み込みに失敗しました: \(error.localizedDescription)")
                }
                return
            }

            self?.completeRequest(error: "非対応の画像形式です")
        }
    }

    // 共有されたファイルを保存しアプリを開く
    private func saveSharedFileAndOpenApp(fileData: Data, fileName: String) {
        do {
            // アプリグループの共有ディレクトリを取得
            guard
                let sharedContainerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.meikenn.tama")
            else {
                completeRequest(error: "共有コンテナにアクセスできません")
                return
            }

            // 一時保存用ディレクトリを確保
            let tempDirURL = sharedContainerURL.appendingPathComponent(
                "PrintSharedFiles", isDirectory: true)
            try FileManager.default.createDirectory(
                at: tempDirURL, withIntermediateDirectories: true)

            // 一時ファイルとしてデータを保存
            let tempFileURL = tempDirURL.appendingPathComponent(UUID().uuidString)
            try fileData.write(to: tempFileURL)

            // ファイル情報をUserDefaultsに保存
            let sharedUserDefaults = UserDefaults(suiteName: "group.com.meikenn.tama")

            let fileInfo: [String: Any] = [
                "tempFileURL": tempFileURL.path,
                "fileName": fileName,
                "fileSize": fileData.count,
                "timestamp": Date().timeIntervalSince1970,
            ]

            sharedUserDefaults?.set(fileInfo, forKey: "SharedPrintFile")
            sharedUserDefaults?.synchronize()

            // アプリを開くためのURLスキームを呼び出す
            if let url = URL(string: "tama://print") {
                openURL(url)
            } else {
                completeRequest(error: "アプリを開くためのURLが無効です")
            }
        } catch {
            completeRequest(error: "ファイル保存エラー: \(error.localizedDescription)")
        }
    }

    private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    self?.completeRequest(error: success ? nil : "アプリを開けませんでした")
                }
                return
            }
            responder = responder?.next
        }

        // UIApplicationが見つからない場合は、extensionContextを使用して閉じる
        completeRequest(error: nil)
    }

    private func completeRequest(error: String?) {
        if let error = error {
            print("共有エラー: \(error)")
        }

        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func getSupportedTypes() -> [UTType] {
        var types: [UTType] = []

        types.append(.pdf)
        types.append(.jpeg)
        types.append(.png)
        types.append(.tiff)
        types.append(.rtf)

        if let doc = UTType("com.microsoft.word.doc") {
            types.append(doc)
        }
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") {
            types.append(docx)
        }
        if let xls = UTType("com.microsoft.excel.xls") {
            types.append(xls)
        }
        if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") {
            types.append(xlsx)
        }
        if let ppt = UTType("com.microsoft.powerpoint.ppt") {
            types.append(ppt)
        }
        if let pptx = UTType("org.openxmlformats.presentationml.presentation") {
            types.append(pptx)
        }

        return types
    }
}
