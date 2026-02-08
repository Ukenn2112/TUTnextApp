// MARK: - TUTnext Core Layer
// This file serves as the entry point for the Core module.
// Import individual components as needed.

// MARK: - Networking
import Foundation

// MARK: - Storage

// MARK: - Errors

// MARK: - Extensions

// MARK: - Protocols

/// Core Layer Module
///
/// This module provides the foundational infrastructure for the TUTnext iOS app:
/// - **Networking**: NetworkClient, APIService, APIEndpoint
/// - **Auth**: AuthService, SessionManager
/// - **Storage**: KeychainManager, UserDefaultsManager, CookieService
/// - **Errors**: AppError, ErrorHandling
/// - **Extensions**: FoundationExtensions, SwiftUIExtensions
/// - **Protocols**: ServiceProtocols, ViewProtocols
///
/// ## Usage
///
/// ```swift
/// import Core
///
/// // Using NetworkClient
/// let response = try await NetworkClient.shared.request(endpoint)
///
/// // Using AuthService
/// let session = try await AuthService.shared.login(account: "user", password: "pass")
///
/// // Using Storage
/// KeychainManager.shared.setString(token, forKey: "accessToken")
/// ```
public struct CoreModule {
    public static let version = "1.0.0"
    public static let minimumiOSVersion = "17.0"
}

// MARK: - Availability Check

@available(iOS 17.0, *)
public struct CoreAvailability {
    public static var isAvailable: Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return true
        }
        #endif
        return false
    }
}
