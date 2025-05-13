//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

import SwiftUI

@main
struct AuthTestApp: App {
    // Create services at the app level
    @StateObject private var auth = AuthenticationCoordinator()
    @StateObject private var userSettings: UserSettings
    
    // Database manager as a singleton
    private let databaseManager = DatabaseManager.shared
    
    // Add this line to initialize SoundManager
    private let soundManager = SoundManager.shared
    
    // Initialize any state objects that need dependencies
    init() {
        // First, create the coordinator
        let coordinator = AuthenticationCoordinator()
        
        // Then create settings with that coordinator, not using self
        let settings = UserSettings(auth: coordinator)
        
        // Now assign to the StateObject property
        self._userSettings = StateObject(wrappedValue: settings)
        
        // Additionally, we need to assign to the auth StateObject
        self._auth = StateObject(wrappedValue: coordinator)
        
        // Ensure sound system is initialized
        print("DEBUG: Initializing sound system...")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(auth)
                .environmentObject(userSettings)
                .onAppear {
                    setupApp()
                    
                    // Add observer for login success notification
                    NotificationCenter.default.addObserver(forName: .userDidLogin, object: nil, queue: .main) { _ in
                        print("DEBUG: Login notification received, syncing data...")
                        syncDataAfterLogin()
                    }
                }
                .onChange(of: auth.isAuthenticated) { newValue in
                    if newValue {
                        print("DEBUG: isAuthenticated changed to true, syncing data...")
                        syncDataAfterLogin()
                    }
                }
        }
    }
    
    private func setupApp() {
        // Initialize anything needed at app launch
        if auth.isAuthenticated {
            // Check and sync quotes if needed on app start
            databaseManager.checkAndSyncQuotesIfNeeded(auth: auth)
        }
    }
    
    private func syncDataAfterLogin() {
        // Sync data after successful login
        databaseManager.syncQuotesFromServer(auth: auth) { success, message in
            if success {
                print("Quotes synced successfully after login")
            } else {
                print("Failed to sync quotes: \(message ?? "Unknown error")")
            }
        }
    }
}
