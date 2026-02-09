//
//  CoreEnvironmentObjects.swift
//  TUTnext
//
//  Core-based EnvironmentObject extensions for dependency injection
//

import SwiftUI

// MARK: - Core Auth Service Environment Object

struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: Core.Auth.AuthService = .shared
}

struct UserServiceKey: EnvironmentKey {
    static let defaultValue: Core.Auth.UserService = .shared
}

extension EnvironmentValues {
    var authService: Core.Auth.AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
    
    var userService: Core.Auth.UserService {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// MARK: - Core Networking Environment Object

struct APIServiceKey: EnvironmentKey {
    static let defaultValue: Core.Networking.APIService = .shared
}

extension EnvironmentValues {
    var apiService: Core.Networking.APIService {
        get { self[APIServiceKey.self] }
        set { self[APIServiceKey.self] = newValue }
    }
}

// MARK: - Core Storage Environment Object

struct UserDefaultsManagerKey: EnvironmentKey {
    static let defaultValue: Core.Storage.UserDefaultsManager = .shared
}

extension EnvironmentValues {
    var userDefaultsManager: Core.Storage.UserDefaultsManager {
        get { self[UserDefaultsManagerKey.self] }
        set { self[UserDefaultsManagerKey.self] = newValue }
    }
}

// MARK: - Convenience View Extensions

extension View {
    /// Inject Core Auth services into environment
    func injectCoreAuthServices() -> some View {
        self.environment(\.authService, .shared)
            .environment(\.userService, .shared)
    }
    
    /// Inject Core Networking services into environment
    func injectCoreNetworkingServices() -> some View {
        self.environment(\.apiService, .shared)
    }
    
    /// Inject Core Storage services into environment
    func injectCoreStorageServices() -> some View {
        self.environment(\.userDefaultsManager, .shared)
    }
    
    /// Inject all Core services into environment
    func injectCoreServices() -> some View {
        self.environment(\.authService, .shared)
            .environment(\.userService, .shared)
            .environment(\.apiService, .shared)
            .environment(\.userDefaultsManager, .shared)
    }
}

// MARK: - Backward Compatibility Extensions

// These extensions allow Views to continue using deprecated Services
// while internally using Core modules

extension View {
    /// Provide legacy AuthService wrapper (internally uses Core)
    func provideLegacyAuthService() -> some View {
        self.environmentObject(AuthService.shared)
    }
    
    /// Provide legacy UserService wrapper (internally uses Core)
    func provideLegacyUserService() -> some View {
        self.environmentObject(UserService.shared)
    }
    
    /// Provide all legacy service wrappers
    func provideLegacyServices() -> some View {
        self.environmentObject(AuthService.shared)
            .environmentObject(UserService.shared)
    }
}
