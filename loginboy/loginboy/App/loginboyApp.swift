//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//


import SwiftUI

@main
struct DecodeyApp: App {
    // Access the centralized service provider
    @StateObject private var serviceProvider = ServiceProvider.shared
    
    // Add this line to initialize SoundManager
    private let soundManager = SoundManager.shared
    
    var body: some Scene {
        WindowGroup {
            // Use the service provider to inject all required environment objects
            serviceProvider.provideEnvironment(
                MainView()
            )
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
    

