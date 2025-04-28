import Foundation
import UIKit

class LanguageService: NSObject, ObservableObject {
    @Published var currentLanguage: String = "日本語"

    static let shared = LanguageService()

    private override init() {
        super.init()
        // 初期化時に現在の言語を取得
        updateCurrentLanguage()
    }

    // 現在の言語を更新
    func updateCurrentLanguage() {
        let preferredLanguage = Locale.preferredLanguages.first ?? "ja"
        let languageCode = preferredLanguage.prefix(2).lowercased()

        switch languageCode {
        case "ja":
            currentLanguage = "日本語"
        case "en":
            currentLanguage = "English"
        case "zh":
            currentLanguage = "简体中文"
        case "ko":
            currentLanguage = "한국어"
        default:
            currentLanguage = "日本語"
        }
    }

    // 言語設定画面を開く
    func openLanguageSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url) { success in
                if success {
                    // 設定アプリから戻ってきたときに言語を再確認するため、
                    // 少し遅延させて確認する
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("設定アプリから戻りました。言語を確認します。")
                        self.updateCurrentLanguage()
                    }
                }
            }
        }
    }
}
