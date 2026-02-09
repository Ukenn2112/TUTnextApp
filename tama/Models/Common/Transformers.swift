//
//  Transformers
//  TUTnext
//
//  Data models for the application
//
import Foundation

/// Date transformation utilities for Codable conformance
public enum DateTransformer {
    /// ISO 8601 date format
    public static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    /// Japanese date format (yyyy-MM-dd)
    public static let japaneseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    /// Japanese datetime format (yyyy-MM-dd HH:mm)
    public static let japaneseDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

/// Color index to/from hex transformation utilities
public enum ColorTransformer {
    /// Default course colors
    public static let defaultColors: [String: String] = [
        "1": "#FF6B6B",
        "2": "#4ECDC4",
        "3": "#45B7D1",
        "4": "#96CEB4",
        "5": "#FFEAA7",
        "6": "#DDA0DD",
        "7": "#98D8C8",
        "8": "#F7DC6F",
        "9": "#BB8FCE",
        "10": "#85C1E9"
    ]
    
    public static func colorIndexToHex(_ index: Int) -> String {
        let key = String(min(index, 10))
        return defaultColors[key] ?? defaultColors["1"]!
    }
    
    public static func hexToColorIndex(_ hex: String) -> Int {
        for (index, color) in defaultColors.values.enumerated() {
            if color == hex {
                return index + 1
            }
        }
        return 1
    }
}
