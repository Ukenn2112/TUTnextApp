import Foundation

// MARK: - TUTNext Models Module
//
// This module provides a complete data layer for the TUTNext application with
// proper Codable support, validation, and repository pattern.
//
// ## Structure
//
// - **Models/**: Domain models with full Codable conformance
//   - **User/**: User authentication and profile models
//   - **Timetable/**: Course schedules and academic calendar models
//   - **Bus/**: Bus schedule and route models
//   - **Assignment/**: Assignment and submission models
//   - **Common/**: Shared utilities (validators, transformers, networking)
//
// - **Mocks/**: Sample data for previews and testing
// - **Repositories/**: Data access layer with async throwing functions
//
// ## Usage
//
// ### Creating a User
//
// ```swift
// let user = User(
//     id: "user-001",
//     username: "taro_tut",
//     fullName: "東京 太郎",
//     email: Email(wrappedValue: "taro@example.com")
// )
// ```
//
// ### Using Repositories
//
// ```swift
// let repository = UserRepository(networkClient: networkClient, storage: storage)
// let user = try await repository.fetchCurrentUser()
// ```
//
// ### Validation
//
// Models support property wrapper validation:
//
// ```swift
// struct UserCredentials: Codable, Validatable {
//     @NonEmpty var username: String
//     @MinLength(minLength: 8) var password: String
// }
// ```
//
// ## Dependencies
//
// - Swift 5.9+
// - Foundation framework
