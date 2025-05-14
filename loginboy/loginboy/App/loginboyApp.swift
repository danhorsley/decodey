//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//


import SwiftUI

// In loginboyApp.swift
@main
struct DecodeyApp: App {
    // Access the centralized service provider
    @StateObject private var serviceProvider = ServiceProvider.shared
    @StateObject private var userState = UserState.shared
    @StateObject private var gameState = GameState.shared
    @StateObject private var settingsState = SettingsState.shared
    
    // Add this line to initialize SoundManager
    private let soundManager = SoundManager.shared
    
    var body: some Scene {
        WindowGroup {
            // Provide all required environment objects
            MainView()
                .environmentObject(userState)
                .environmentObject(gameState)
                .environmentObject(settingsState)
                .onAppear {
                    print("App Started")
                    
                    // Initialize data on app start
                    Task {
                        // Check for saved authentication
                        if serviceProvider.authCoordinator.isAuthenticated {
                            // Load user data if authenticated
                            serviceProvider.userService.loadUserData()
                        }
                        
                        // Check for database initialization
                        if UserDefaults.standard.bool(forKey: "firstLaunch") == false {
                            UserDefaults.standard.set(true, forKey: "firstLaunch")
                        }
                    }
                }
        }
    }
}
    

