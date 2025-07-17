import Combine
import CoreNFC
import Foundation

// Shift-JIS デコーディングのためのヘルパー拡張
extension Data {
    func string(encoding: String.Encoding) -> String? {
        return String(data: self, encoding: encoding)
    }

    // 16進数文字列表現のためのヘルパーメソッド
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined()
    }
}

// NFC読み取り中に発生する可能性のあるエラーを定義
enum NFCReadError: LocalizedError {
    case nfcNotAvailable
    case sessionInvalidated(reason: String)
    case tagConnectionFailed
    case unexpectedTagType
    case readFailed(serviceCode: String, blockIndex: Int)
    case dataDecodingFailed(description: String)
    case missingData(description: String)

    var errorDescription: String? {
        switch self {
        case .nfcNotAvailable:
            return "NFCリーダーはこのデバイスで利用できません。"
        case .sessionInvalidated(let reason):
            return "NFCセッションが無効になりました: \(reason)"
        case .tagConnectionFailed:
            return "カードへの接続に失敗しました。"
        case .unexpectedTagType:
            return "予期しないカードタイプです。FeliCaカードを使用してください。"
        case .readFailed(let serviceCode, let blockIndex):
            return "カードデータの読み取りに失敗しました (サービス: \(serviceCode), ブロック: \(blockIndex))。"
        case .dataDecodingFailed(let description):
            return "データのデコードに失敗しました: \(description)"
        case .missingData(let description):
            return "必要なデータが見つかりませんでした: \(description)"
        }
    }
}

// NFC読み取りロジックを処理し結果を公開するObservableObject
class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {

    @Published var studentID: String = ""
    @Published var userName: String = ""
    @Published var errorMessage: String? = nil

    private var session: NFCTagReaderSession?

    // FeliCaカード定数
    private let felicaSystemCode = Data([0x80, 0x9E])  // システムコード 0x809E
    private let serviceCodeStudentInfo = Data([0x0B, 0x10])  // サービスコード 0x100B (リトルエンディアン)
    private let serviceCodePersonalInfo = Data([0x0B, 0x20])  // サービスコード 0x200B (リトルエンディアン)

    // NFC読み取りセッションを開始する関数
    func startSession() {
        guard NFCTagReaderSession.readingAvailable else {
            self.errorMessage = NFCReadError.nfcNotAvailable.localizedDescription
            print("NFCはこのデバイスで利用できません。")
            return
        }

        // 既存のセッションがある場合は無効化
        session?.invalidate()

        // FeliCaタグ用の新しいセッションを作成
        session = NFCTagReaderSession(pollingOption: [.iso18092], delegate: self, queue: nil)
        session?.alertMessage = NSLocalizedString("学生証をiPhoneの上部に近づけてください。", comment: "")
        session?.begin()
        print("NFCセッション開始")
    }

    // MARK: - NFCTagReaderSessionDelegate メソッド

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("NFCセッションがアクティブになりました")
        DispatchQueue.main.async {
            self.errorMessage = nil  // セッションがアクティブになったら以前のエラーをクリア
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // セッション無効化の処理 (ユーザーキャンセル、タイムアウト、システムエラーなど)
        print("NFCセッションが無効化されました: \(error.localizedDescription)")

        var displayMessage: String? = nil
        let nsError = error as NSError

        // NFCErrorDomainグローバル定数を使用してドメインを確認し、
        // エラーコードで直接切り替える
        if nsError.domain == NFCErrorDomain {
            switch nsError.code {
            case 200:  // readerSessionInvalidationErrorUserCanceled に対応
                print("ユーザーがNFCセッションをキャンセルしました。")
            // メッセージは不要
            case 201:  // readerSessionInvalidationErrorSessionTimeout に対応
                displayMessage = NSLocalizedString("NFCセッションがタイムアウトしました。", comment: "")
                print("NFCセッションがタイムアウトしました。")
            case 202:  // readerSessionInvalidationErrorSystemIsBusy に対応
                displayMessage = NSLocalizedString(
                    "NFCシステムがビジー状態です。しばらくしてから再試行してください。", comment: "")
                print("NFCシステムがビジー状態です。")
            // 必要に応じてNFCError.Codeから他の既知の整数コードを追加
            default:
                // 他のNFC固有のエラーを処理するか、一般的なメッセージにフォールバック
                displayMessage =
                    NFCReadError.sessionInvalidated(reason: error.localizedDescription)
                    .localizedDescription
                print("NFCセッションがNFCエラーコード \(nsError.code)で無効化されました: \(error.localizedDescription)")
            }
        } else {
            // エラーはNFCErrorドメインではない
            displayMessage =
                NFCReadError.sessionInvalidated(reason: error.localizedDescription)
                .localizedDescription
            print("NFCエラー以外でセッションが無効化されました: \(error)")
        }

        DispatchQueue.main.async {
            self.errorMessage = displayMessage
        }
        self.session = nil  // セッション参照をクリーンアップ
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("NFCタグ検出: \(tags.count)個")
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: NSLocalizedString("カードが見つかりませんでした。", comment: ""))
            return
        }

        // 検出されたタグがFeliCaタグであることを確認
        guard case .feliCa(let felicaTag) = firstTag else {
            session.invalidate(errorMessage: NFCReadError.unexpectedTagType.localizedDescription)
            print("検出されたタグはFeliCaタイプではありません。")
            return
        }

        print("FeliCaタグを検出しました。接続中...")

        // FeliCaタグに接続
        Task {  // 非同期操作にTaskを使用
            do {
                try await session.connect(to: firstTag)
                print("FeliCaタグに接続しました。")

                // 接続後に現在のシステムコードに直接アクセス
                let currentSystemCode = felicaTag.currentSystemCode
                print("現在のシステムコード: \(currentSystemCode.hexEncodedString())")
                // 注意: currentIDmとcurrentSystemCodeは接続後に利用可能

                // システムコードが0x809Eと一致するか確認
                guard currentSystemCode == self.felicaSystemCode else {
                    session.invalidate(
                        errorMessage:
                            "対応していないカードです (システムコード: \(currentSystemCode.hexEncodedString()))。")
                    print(
                        "システムコードの不一致。期待: \(self.felicaSystemCode.hexEncodedString()), 取得: \(currentSystemCode.hexEncodedString())"
                    )
                    return
                }
                print("システムコード 0x809E を確認しました。")

                // データブロックの読み取り
                let studentInfoData = try await readFeliCaBlocks(
                    session: session, tag: felicaTag, serviceCode: serviceCodeStudentInfo,
                    blocks: [1, 3, 6, 7])  // 名前のためにブロック6,7を追加
                let personalInfoData = try await readFeliCaBlocks(
                    session: session, tag: felicaTag, serviceCode: serviceCodePersonalInfo,
                    blocks: [1])  // 学生ID接尾辞のためにブロック1のみ必要

                // 読み取ったデータを処理
                try processFeliCaData(studentInfo: studentInfoData, personalInfo: personalInfoData)

                // 読み取り後にセッションを正常に無効化
                session.alertMessage = NSLocalizedString("読み取り成功！", comment: "")
                session.invalidate()
                print("NFC読み取り成功。")

            } catch let error as NFCReadError {
                print("NFC読み取りエラー: \(error.localizedDescription)")
                session.invalidate(errorMessage: error.localizedDescription)
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            } catch {
                print("NFC操作中の一般エラー: \(error.localizedDescription)")
                session.invalidate(errorMessage: "読み取り中にエラーが発生しました: \(error.localizedDescription)")
                Task { @MainActor in
                    self.errorMessage = "読み取り中にエラーが発生しました: \(error.localizedDescription)"
                }
            }
        }
    }

    // FeliCaサービスから複数のブロックを読み取るヘルパー関数
    private func readFeliCaBlocks(
        session: NFCTagReaderSession, tag: NFCFeliCaTag, serviceCode: Data, blocks: [Int]
    ) async throws -> [Data] {
        print("サービスコード: \(serviceCode.hexEncodedString()), ブロック: \(blocks) を読み取り中")

        // readWithoutEncryptionから返されるタプルを正しく分解
        let (status1, status2, readData) = try await tag.readWithoutEncryption(
            serviceCodeList: [serviceCode],
            blockList: blocks.map { Data([0x80, UInt8($0)]) }  // ブロック形式 [0x80, index]
        )

        print("読み取りステータス: Status1=\(status1), Status2=\(status2)")

        // ステータスフラグを確認（成功の場合、status1とstatus2は0）
        guard status1 == 0x00, status2 == 0x00 else {
            print("ステータスフラグでの読み取り失敗: Status1=\(status1), Status2=\(status2)")
            throw NFCReadError.readFailed(
                serviceCode: serviceCode.hexEncodedString(), blockIndex: -1)  // サービスの一般的な読み取り失敗を示す
        }

        // 期待されるブロック数を受け取ったことを確認
        guard readData.count == blocks.count else {
            print("読み取り失敗: 期待ブロック数 \(blocks.count), 取得ブロック数 \(readData.count)")
            throw NFCReadError.readFailed(
                serviceCode: serviceCode.hexEncodedString(), blockIndex: -1)
        }

        print("サービスコード \(serviceCode.hexEncodedString()) の \(readData.count) ブロックを正常に読み取りました")
        return readData  // 実際のブロックデータ配列を返す
    }

    // カードから読み取った生データを処理
    private func processFeliCaData(studentInfo: [Data], personalInfo: [Data]) throws {
        // readFeliCaBlocksの呼び出しに基づく期待カウント
        guard studentInfo.count == 4 else {
            throw NFCReadError.missingData(description: "学生情報ブロックが不足しています。")
        }
        guard personalInfo.count == 1 else {
            throw NFCReadError.missingData(description: "個人情報ブロックが不足しています。")
        }

        // --- 学生ID ---
        // 0x100B[01] -> studentInfo[0]
        // 0x200B[01] -> personalInfo[0]
        guard let idPart1 = studentInfo[0].string(encoding: .ascii),
            let idPart2 = personalInfo[0].string(encoding: .ascii)
        else {
            throw NFCReadError.dataDecodingFailed(description: "学籍番号のデコードに失敗しました (ASCII)。")
        }

        let fullStudentID =
            (idPart1.trimmingCharacters(in: .whitespacesAndNewlines)
            + idPart2.trimmingCharacters(in: .whitespacesAndNewlines))
            .trimmingCharacters(in: .whitespacesAndNewlines)  // 念のため最終トリム

        // --- 有効期限 ---
        // 0x100B[03] -> studentInfo[1]
        if let validityString = studentInfo[1].string(encoding: .ascii)?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        {
            let startDate = String(validityString.prefix(8))  // YYYYMMDD
            let endDate = String(validityString.suffix(8))  // YYYYMMDD
            print("有効期限: \(startDate) から \(endDate) まで")
        }

        // --- 氏名 ---
        // 0x100B[06] (姓) -> studentInfo[2]
        // 0x100B[07] (名) -> studentInfo[3]
        let lastNameData = studentInfo[2]
        let firstNameData = studentInfo[3]

        // Shift-JISをデコード、無効なシーケンスに対するフォールバックを提供
        let shiftJISEncoding = String.Encoding.shiftJIS
        guard let lastName = String(data: lastNameData, encoding: shiftJISEncoding),
            let firstName = String(data: firstNameData, encoding: shiftJISEncoding)
        else {
            throw NFCReadError.dataDecodingFailed(description: "氏名のデコードに失敗しました (Shift-JIS)。")
        }

        // スペース、数字、その他の不要な文字を削除して名前文字列をクリーンアップ
        let unwantedCharacters = CharacterSet.whitespaces
            .union(.decimalDigits)
            .union(.controlCharacters)

        let cleanLastNameTemp =
            lastName
            .components(separatedBy: unwantedCharacters)
            .joined()
            .trimmingCharacters(in: unwantedCharacters)

        let cleanFirstNameTemp =
            firstName
            .components(separatedBy: unwantedCharacters)
            .joined()
            .trimmingCharacters(in: unwantedCharacters)

        let cleanLastName =
            cleanLastNameTemp.applyingTransform(.fullwidthToHalfwidth, reverse: true)
            ?? cleanLastNameTemp
        let cleanFirstName =
            cleanFirstNameTemp.applyingTransform(.fullwidthToHalfwidth, reverse: true)
            ?? cleanFirstNameTemp

        let fullUserName = cleanLastName + " " + cleanFirstName

        print("処理された学生ID: \(fullStudentID)")
        print("処理されたユーザー名: \(fullUserName)")

        // メインスレッドで公開プロパティを更新
        DispatchQueue.main.async {
            self.studentID = fullStudentID
            self.userName = fullUserName
            self.errorMessage = nil  // 成功時にエラーをクリア
        }
    }
}
