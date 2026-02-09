import Foundation
import CoreNFC

// MARK: - NFC Reader

/// NFC Reader service for reading student ID cards (FeliCa)
/// Provides student ID and user name extraction from physical student cards
@MainActor
final class NFCReader: NFCReaderProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var studentID: String = ""
    @Published private(set) var userName: String = ""
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var isScanning: Bool = false
    
    // MARK: - Private Properties
    
    private var session: NFCTagReaderSession?
    private let felicaSystemCode = Data([0x80, 0x9E])
    private let serviceCodeStudentInfo = Data([0x0B, 0x10])
    private let serviceCodePersonalInfo = Data([0x0B, 0x20])
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        session?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Starts NFC scanning session for student ID card
    func startSession() {
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = NFCError.notAvailable.localizedDescription
            print("[NFC] NFC not available on this device")
            return
        }
        
        session?.invalidate()
        
        session = NFCTagReaderSession(pollingOption: .iso18092, delegate: self, queue: nil)
        session?.alertMessage = "学生証をiPhoneの上部に近づけてください。"
        session?.begin()
        
        isScanning = true
        errorMessage = nil
        print("[NFC] Session started")
    }
    
    /// Invalidates the current NFC session
    func invalidateSession() {
        session?.invalidate()
        session = nil
        isScanning = false
    }
    
    /// Clears all stored data
    func clearData() {
        studentID = ""
        userName = ""
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func readFeliCaBlocks(
        tag: NFCFeliCaTag,
        serviceCode: Data,
        blocks: [Int]
    ) async throws -> [Data] {
        print("[NFC] Reading blocks: \(blocks) for service: \(serviceCode.hexEncodedString())")
        
        let (status1, status2, readData) = try await tag.readWithoutEncryption(
            serviceCodeList: [serviceCode],
            blockList: blocks.map { Data([0x80, UInt8($0)]) }
        )
        
        guard status1 == 0x00 && status2 == 0x00 else {
            print("[NFC] Read failed with status: \(status1), \(status2)")
            throw NFCError.readFailed(serviceCode: serviceCode.hexEncodedString(), blockIndex: -1)
        }
        
        guard readData.count == blocks.count else {
            throw NFCError.readFailed(serviceCode: serviceCode.hexEncodedString(), blockIndex: -1)
        }
        
        print("[NFC] Successfully read \(readData.count) blocks")
        return readData
    }
    
    private func processCardData(studentInfo: [Data], personalInfo: [Data]) throws -> NFCReadResult {
        // Validate data count
        guard studentInfo.count >= 4 else {
            throw NFCError.missingData(description: "Student info blocks insufficient")
        }
        guard personalInfo.count >= 1 else {
            throw NFCError.missingData(description: "Personal info blocks insufficient")
        }
        
        // Extract student ID
        guard let idPart1 = studentInfo[0].string(encoding: .ascii),
              let idPart2 = personalInfo[0].string(encoding: .ascii)
        else {
            throw NFCError.dataDecodingFailed(description: "Student ID decoding failed (ASCII)")
        }
        
        let studentID = (idPart1 + idPart2).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract validity dates
        var validityStart: String?
        var validityEnd: String?
        if let validityString = studentInfo[1].string(encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            validityStart = String(validityString.prefix(8))
            validityEnd = String(validityString.suffix(8))
            print("[NFC] Validity: \(validityStart ?? "N/A") to \(validityEnd ?? "N/A")")
        }
        
        // Extract user name (Shift-JIS encoded)
        let shiftJIS = String.Encoding.shiftJIS
        guard let lastName = String(data: studentInfo[2], encoding: shiftJIS),
              let firstName = String(data: studentInfo[3], encoding: shiftJIS)
        else {
            throw NFCError.dataDecodingFailed(description: "User name decoding failed (Shift-JIS)")
        }
        
        let userName = cleanUserName(lastName: lastName, firstName: firstName)
        
        return NFCReadResult(
            studentID: studentID,
            userName: userName,
            validityStart: validityStart,
            validityEnd: validityEnd
        )
    }
    
    private func cleanUserName(lastName: String, firstName: String) -> String {
        let unwantedCharacters = CharacterSet.whitespaces
            .union(.decimalDigits)
            .union(.controlCharacters)
        
        let cleanLast = lastName
            .components(separatedBy: unwantedCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanFirst = firstName
            .components(separatedBy: unwantedCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fullwidthToHalfwidth = cleanLast.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? cleanLast
        let givenNameConverted = cleanFirst.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? cleanFirst
        
        return "\(fullwidthToHalfwidth) \(givenNameConverted)"
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCReader: NFCTagReaderSessionDelegate {
    
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Task { @MainActor in
            self.errorMessage = nil
            print("[NFC] Session active")
        }
    }
    
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            
            let nsError = error as NSError
            if nsError.domain == NFCErrorDomain {
                switch nsError.code {
                case 200:
                    print("[NFC] User cancelled")
                case 201:
                    self.errorMessage = NFCError.sessionTimeout.localizedDescription
                case 202:
                    self.errorMessage = NFCError.systemBusy.localizedDescription
                default:
                    self.errorMessage = NFCError.sessionInvalidated(reason: error.localizedDescription).localizedDescription
                }
            } else {
                self.errorMessage = NFCError.sessionInvalidated(reason: error.localizedDescription).localizedDescription
            }
            
            self.session = nil
            print("[NFC] Session invalidated: \(error.localizedDescription)")
        }
    }
    
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Task { @MainActor in
            guard let firstTag = tags.first else {
                session.invalidate(errorMessage: "カードが見つかりませんでした。")
                return
            }
            
            guard case .feliCa(let felicaTag) = firstTag else {
                session.invalidate(errorMessage: NFCError.unexpectedTagType.localizedDescription)
                return
            }
            
            print("[NFC] FeliCa tag detected")
            self.readCardData(session: session, tag: felicaTag)
        }
    }
    
    // MARK: - Private Methods
    
    private func readCardData(session: NFCTagReaderSession, tag: NFCFeliCaTag) {
        Task {
            do {
                try await session.connect(to: tag)
                print("[NFC] Connected to tag")
                
                let systemCode = tag.currentSystemCode
                guard systemCode == felicaSystemCode else {
                    session.invalidate(errorMessage: "対応していないカードです。")
                    return
                }
                print("[NFC] System code verified: \(systemCode.hexEncodedString())")
                
                let studentInfo = try await readFeliCaBlocks(
                    tag: tag,
                    serviceCode: serviceCodeStudentInfo,
                    blocks: [1, 3, 6, 7]
                )
                
                let personalInfo = try await readFeliCaBlocks(
                    tag: tag,
                    serviceCode: serviceCodePersonalInfo,
                    blocks: [1]
                )
                
                let result = try processCardData(studentInfo: studentInfo, personalInfo: personalInfo)
                
                self.studentID = result.studentID
                self.userName = result.userName
                self.errorMessage = nil
                
                session.alertMessage = "読み取り成功！"
                session.invalidate()
                self.isScanning = false
                
                print("[NFC] Read success: ID=\(result.studentID), Name=\(result.userName)")
                
            } catch let error as NFCError {
                session.invalidate(errorMessage: error.localizedDescription)
                self.errorMessage = error.localizedDescription
                self.isScanning = false
                print("[NFC] NFC error: \(error.localizedDescription)")
            } catch {
                session.invalidate(errorMessage: "読み取りエラー: \(error.localizedDescription)")
                self.errorMessage = "読み取りエラー: \(error.localizedDescription)"
                self.isScanning = false
                print("[NFC] Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Data Helper Extension

extension Data {
    func string(encoding: String.Encoding) -> String? {
        String(data: self, encoding: encoding)
    }
    
    func hexEncodedString() -> String {
        map { String(format: "%02hhX", $0) }.joined()
    }
}
