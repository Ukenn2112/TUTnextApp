import Foundation
import SwiftUI
import UniformTypeIdentifiers

class PrintSystemViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var printSettings = PrintSettings()
    @Published var selectedFile: (data: Data, name: String, size: Int)?
    @Published var printResult: PrintResult?
    @Published var showFileSelector = false
    @Published var showResultView = false
    @Published var recentUploads: [PrintResult] = []
    
    // PIN番号
    @Published var pinCode: String = ""
    
    init() {
        // 初期化時に共有されたファイルを確認
        checkForSharedFile()
    }
    
    // 共有拡張機能から共有されたファイルを確認
    private func checkForSharedFile() {
        guard let sharedUserDefaults = UserDefaults(suiteName: "group.com.meikenn.tama"),
              let fileInfo = sharedUserDefaults.dictionary(forKey: "SharedPrintFile") else {
            return
        }
        
        // ファイル情報を取得
        guard let tempFilePath = fileInfo["tempFileURL"] as? String,
              let fileName = fileInfo["fileName"] as? String,
              let fileSize = fileInfo["fileSize"] as? Int else {
            return
        }
        
        let tempFileURL = URL(fileURLWithPath: tempFilePath)
        
        do {
            // ファイルデータを読み込む
            let fileData = try Data(contentsOf: tempFileURL)
            
            // ViewModel内のselectedFileに設定
            DispatchQueue.main.async { [weak self] in
                self?.selectedFile = (data: fileData, name: fileName, size: fileSize)
            }
            
            // 使用済みのファイル情報を削除
            sharedUserDefaults.removeObject(forKey: "SharedPrintFile")
            
            // 一時ファイルを削除
            try FileManager.default.removeItem(at: tempFileURL)
        } catch {
            print("共有ファイルの読み込みエラー: \(error.localizedDescription)")
            // エラーがあっても共有情報は削除
            sharedUserDefaults.removeObject(forKey: "SharedPrintFile")
        }
    }
    
    // 印刷システムにログインする
    func login(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        PrintSystemService.shared.login { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if !success {
                    self?.errorMessage = error?.localizedDescription ?? "ログインに失敗しました"
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // ファイルを選択する
    func selectFile() {
        showFileSelector = true
    }
    
    // ファイルがインポートされた時の処理
    func handleImportedFile(url: URL) {
        do {
            let fileData = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let fileSize = fileData.count
            
            DispatchQueue.main.async { [weak self] in
                self?.selectedFile = (data: fileData, name: fileName, size: fileSize)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // 最近のアップロード履歴を保存
    func addRecentUpload(_ result: PrintResult) {
        // 新しい結果を先頭に追加
        recentUploads.insert(result, at: 0)
        // 最大10件まで保持
        if recentUploads.count > 10 {
            recentUploads.removeLast()
        }
        // UserDefaultsに保存
        saveRecentUploads()
    }
    
    // 最近のアップロード履歴をUserDefaultsに保存
    private func saveRecentUploads() {
        if let encoded = try? JSONEncoder().encode(recentUploads) {
            UserDefaults.standard.set(encoded, forKey: "recentUploads")
        }
    }
    
    // 最近のアップロード履歴をUserDefaultsから読み込み
    func loadRecentUploads() {
        if let data = UserDefaults.standard.data(forKey: "recentUploads"),
           let decoded = try? JSONDecoder().decode([PrintResult].self, from: data) {
            recentUploads = decoded
        }
    }
    
    // ファイルをアップロードする
    func uploadFile() {
        guard let selectedFile = selectedFile else {
            errorMessage = "ファイルが選択されていません"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // PINコードがある場合は設定に追加
        var settings = printSettings
        if !pinCode.isEmpty {
            settings.pin = pinCode
        }
        
        PrintSystemService.shared.uploadFile(
            fileData: selectedFile.data, 
            fileName: selectedFile.name, 
            settings: settings
        ) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "アップロードに失敗しました: \(error.localizedDescription)"
                } else if let result = result {
                    self?.printResult = result
                    self?.addRecentUpload(result) // アップロード成功時に履歴に追加
                    self?.showResultView = true
                }
            }
        }
    }
    
    // すべての状態をリセットする
    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.selectedFile = nil
            self?.printSettings = PrintSettings()
            self?.pinCode = ""
            self?.printResult = nil
            self?.errorMessage = nil
            self?.showResultView = false
        }
    }
    
    // ファイルサイズを人間が読みやすい形式で表示
    func formattedFileSize(bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // 印刷可能なファイル形式の取得
    func supportedDocumentTypes() -> [UTType] {
        var types: [UTType] = []
        
        // 標準的なUTType
        types.append(.pdf)
        types.append(.jpeg)
        types.append(.png)
        types.append(.tiff)
        types.append(.rtf)
        
        // カスタムUTType
        if let xdw = UTType("com.fujifilm.xdw") {
            types.append(xdw)
        }
        if let xbd = UTType("com.fujifilm.xbd") {
            types.append(xbd)
        }
        if let xps = UTType("com.microsoft.xps") {
            types.append(xps)
        }
        if let oxps = UTType("com.microsoft.oxps") {
            types.append(oxps)
        }
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