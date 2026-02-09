import Foundation

// MARK: - Data拡張

extension Data {
    /// Shift-JISデコーディングのための文字列変換
    func string(encoding: String.Encoding) -> String? {
        return String(data: self, encoding: encoding)
    }

    /// 16進数文字列表現
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined()
    }
}
