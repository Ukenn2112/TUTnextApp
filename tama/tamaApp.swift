//
//  tamaApp.swift
//  tama
//
//  Created by 维安雨轩 on 2025/02/27.
//

import SwiftUI
import SwiftData

@main
struct tamaApp: App {
    @StateObject private var appearanceManager = AppearanceManager()
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearanceManager)
                .preferredColorScheme(appearanceManager.isDarkMode ? .dark : .light)
                .onAppear {
                    appearanceManager.startObservingSystemAppearance()
                }
        }
    }
}
