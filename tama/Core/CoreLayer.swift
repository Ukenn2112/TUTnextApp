//
//  CoreLayer.swift
//  TUTNext
//
//  Core layer architecture for the TUTNext iOS app
//  Compatible with iOS 17.0+ and Swift 5.9
//

import Foundation

// MARK: - Core Layer Overview

/*
 The Core layer provides foundational services and utilities:
 
 1. Networking
    - NetworkClient: Low-level HTTP client with interceptors
    - APIService: Business logic API calls
    - Interceptors: Request/response transformation
 
 2. Authentication
    - AuthService: Login/logout operations
    - SessionManager: Session state management
    - UserService: User data management
 
 3. Storage
    - KeychainManager: Secure storage for sensitive data
    - UserDefaultsManager: Preferences storage
    - CookieService: HTTP cookie management
 
 4. Error Handling
    - AppError: Comprehensive error enum
    - Result types for async operations
    - Retry policies
 
 5. Extensions
    - FoundationExtensions: Standard library enhancements
    - ViewExtensions: SwiftUI view utilities
 
 6. Protocols
    - ServiceProtocols: Service abstractions
    - ViewProtocols: View layer contracts
 */

// MARK: - Import Statements

/*
 All Core modules are auto-imported in Xcode via project configuration.
 Individual files can be imported as needed:
 
 import Core
 import Core.Networking
 import Core.Auth
 import Core.Storage
 import Core.Errors
 import Core.Extensions
 import Core.Protocols
 */

// MARK: - Availability

@available(iOS 17.0, *)
public struct CoreLayer {
    public static let version = "1.0.0"
    
    public init() {}
}

// MARK: - Module Exports

@_exported import Foundation
@_exported import SwiftUI
