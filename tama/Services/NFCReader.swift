import Foundation
import CoreNFC

/// Stub NFC Reader - functionality to be migrated to Core modules
@MainActor
final class NFCReader: ObservableObject {
    @Published var studentID: String = ""
    @Published var userName: String = ""
    @Published var errorMessage: String?
    
    func startSession() {
        // NFC functionality removed - to be implemented in Core.NFC module
    }
}
